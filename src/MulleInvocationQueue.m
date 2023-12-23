//
//  main.m
//  archiver-test
//
//  Created by Nat! on 19.04.16.
//  Copyright © 2016 Mulle kybernetiK. All rights reserved.
//
#import "MulleInvocationQueue.h"

#import "import-private.h"


@class MulleInvocationQueue;


NS_OPTIONS_TABLE( MulleInvocationQueueState, 9) =
{
   NS_OPTIONS_ITEM( MulleInvocationQueueInit),
   NS_OPTIONS_ITEM( MulleInvocationQueueIdle),
   NS_OPTIONS_ITEM( MulleInvocationQueueRun),
   NS_OPTIONS_ITEM( MulleInvocationQueueEmpty),
   NS_OPTIONS_ITEM( MulleInvocationQueueDone),
   NS_OPTIONS_ITEM( MulleInvocationQueueError),
   NS_OPTIONS_ITEM( MulleInvocationQueueException),
   NS_OPTIONS_ITEM( MulleInvocationQueueCancel),
   NS_OPTIONS_ITEM( MulleInvocationQueueNotified)
};


@implementation MulleInvocationQueue


+ (instancetype) invocationQueue
{
   return( [[[self alloc] initWithCapacity:1024] autorelease]);
}


- (instancetype) initWithCapacity:(NSUInteger) capacity
{
   mulle_thread_mutex_init( &_queueLock);
   mulle_pointerqueue_init( &_queue, capacity / 8, 8, MulleObjCInstanceGetAllocator( self));

   return( self);
}


#ifdef DEBUG
- (id) retain
{
   return( [super retain]);
}
#endif


- (void) finalize
{
   [self terminate];

   // get rid of invocations, which retain stuff
   [self _discardInvocations];
   [_finalInvocation autorelease];
   _finalInvocation = nil;

   [super finalize];
}


- (void) dealloc
{
   NSInvocation   *invocation;

   [_executionThread release];
   [_exception release];


   // safety..., no need to lock though
   while( (invocation = mulle_pointerqueue_pop( &_queue)))
      [invocation release];
   mulle_pointerqueue_done( &_queue);
   mulle_thread_mutex_done( &_queueLock);

   [super dealloc];
}


- (BOOL) isExecutionThread
{
   return( ! _executionThread || [NSThread currentThread] == _executionThread);
}


- (NSUInteger) state
{
   NSUInteger   state;

   state = (NSUInteger) _mulle_atomic_pointer_read( &_state);
   fprintf( stderr, "queue %p state is %s\n", self, MulleInvocationQueueStateUTF8String( state));
   return( state);
}


- (void) _setState:(NSUInteger) state
{
   _mulle_atomic_pointer_write( &_state, (void *) state);

   if( _messageDelegateOnExecutionThread && [self isExecutionThread])
   {
      [_delegate invocationQueueDidChangeState:self];
      state = state | MulleInvocationQueueNotified;
      _mulle_atomic_pointer_write( &_state, (void *) state);
   }
}


- (NSUInteger) numberOfInvocations
{
   NSUInteger   count;

   mulle_thread_mutex_lock( &_queueLock);
   count = mulle_pointerqueue_get_count( &_queue);
   mulle_thread_mutex_unlock( &_queueLock);
   return( count);
}


- (void) addInvocation:(NSInvocation *) invocation
{
   [invocation retainArguments];
   [invocation retain];

   mulle_thread_mutex_lock( &_queueLock);
   mulle_pointerqueue_push( &_queue, invocation);
   mulle_thread_mutex_unlock( &_queueLock);

   [_executionThread nudge];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   [_finalInvocation autorelease];
   _finalInvocation = [invocation retain];

   [self addInvocation:invocation];
}


- (void) _discardInvocations
{
   NSInvocation   *invocation;

   mulle_thread_mutex_lock( &_queueLock);
   while( (invocation = mulle_pointerqueue_pop( &_queue)))
      [invocation autorelease];
   mulle_thread_mutex_unlock( &_queueLock);
}


- (void) _finalizing:(NSInvocation *) invocation
{
   assert( [self isExecutionThread]);

   [_finalInvocation autorelease];
   _finalInvocation = nil;
}


- (int) invokeNextInvocation:(id) unused
{
   NSInvocation   *invocation;

   assert( [self isExecutionThread]);

   mulle_thread_mutex_lock( &_queueLock);
   invocation = mulle_pointerqueue_pop( &_queue);
   mulle_thread_mutex_unlock( &_queueLock);

   if( ! invocation)
   {
      if( _doneOnEmptyQueue)
      {
         [self _finalizing:invocation];  // do this before _setState:
         [self _setState:MulleInvocationQueueDone];
         return( MulleThreadGoIdle);
      }
      [self _setState:MulleInvocationQueueEmpty];
      return( MulleThreadGoIdle);
   }

   [self _setState:MulleInvocationQueueRun];

   invocation = [invocation autorelease];
   if( _trace)
      fprintf( stderr, "queue %p executes %s", self, [invocation invocationUTF8String]);

   if( _catchesExceptions)
   {
      @try
      {
         [invocation invoke];
      }
      @catch( NSObject *exception)
      {
         if( _ignoresCaughtExceptions)
            return( MulleThreadContinueMain);

         [_exception autorelease];
         _exception = [exception retain];

         [self _discardInvocations];
         [self _setState:MulleInvocationQueueException];
         return( MulleThreadCancelMain);
      }
   }
   else
   {
      [invocation invoke];
   }

   if( _cancelsOnFailedReturnStatus && [invocation mulleReturnStatus])
   {
      [self _discardInvocations];
      [self _setState:MulleInvocationQueueError];
      return( MulleThreadCancelMain);
   }

   if( _finalInvocation == invocation)
   {
      [self _setState:MulleInvocationQueueDone];
      [self _finalizing:invocation]; // do this after _setState:
      return( MulleThreadCancelMain);
   }

   return( MulleThreadContinueMain);
}


- (void) start
{
   NSUInteger   options;

   if( ! _executionThread)
   {
      options          = MulleThreadDontRetainTarget|MulleThreadDontReleaseTarget;
      _executionThread = [[MulleThread alloc] mulleInitWithTarget:self
                                                        selector:@selector( invokeNextInvocation:)
                                                          object:nil
                                                         options:options];
   }
   [_executionThread start];
}  


- (void) preempt
{
   [_executionThread preempt];
}


- (void) cancelWhenIdle
{
   NSUInteger   state;

   for(;;)
   {
      state = [self state];
      switch( state & ~MulleInvocationQueueNotified)
      {
      case MulleInvocationQueueInit      :
         [_executionThread nudge];
         break;

      case MulleInvocationQueueRun       :
         break;

      case MulleInvocationQueueIdle      :
      case MulleInvocationQueueEmpty     :
      case MulleInvocationQueueDone      :
      case MulleInvocationQueueError     :
      case MulleInvocationQueueException :
      case MulleInvocationQueueCancel    :
         [_executionThread cancelWhenIdle];
         return;
      }
      [_executionThread blockUntilNoLongerBusy];
   }
}


- (int) terminate
{
   if( ! _executionThread)
      return( -1);

   if( _terminateWaitsForCompletion)
      [self cancelWhenIdle];
   else
      [_executionThread preempt];
   return( 0);
}


// returns 1 if running
- (BOOL) poll
{
   NSUInteger   state;

   assert( [NSThread currentThread] != _executionThread);

   state = [self state];
   if( ! (state & MulleInvocationQueueNotified))
   {
      if( ! _messageDelegateOnExecutionThread && ! [self isExecutionThread])
      {
         [self _setState:state|MulleInvocationQueueNotified];
         [_delegate invocationQueueDidChangeState:self];
      }
   }

   return( (state & ~MulleInvocationQueueNotified) == MulleInvocationQueueRun);
}

@end 



#if 0

#define UIInvocationQueueEventType  @selector( UIInvocationQueueEvent)


@interface UIInvocationQueueEvent : UIUserEvent

- (instancetype) initWithInvocationQueue:(MulleInvocationQueue *) queue;

@property( assign, readonly) MulleInvocationQueue   *invocationQueue;

@end


@implementation UIInvocationQueueEvent

- (instancetype) initWithInvocationQueue:(MulleInvocationQueue *) queue
{
   assert( windowInfo);

   [self initWithEventIdentifier:UIInvocationQueueEventType];
   _invocationQueue = [queue retain];
   return( self);
}


- (void) dealloc
{
   [_invocationQueue release];
   [super dealloc];
}


- (char *) _payloadUTF8String
{
   return( MulleObjC_asprintf( "invocationQueue=%#@", _invocationQueue));
}

@end

#endif
