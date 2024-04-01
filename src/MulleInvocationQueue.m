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


static void   MulleInvocationQueuePush( MulleInvocationQueue *self,
                                        NSInvocation *invocation)
{
   mulle_thread_mutex_do( self->_queueLock)
   {
      [invocation retainArguments];
      [invocation retain];
      assert( ! self->_finalInvocation);

      [invocation mulleRelinquishAccess];
      mulle_pointerqueue_push( &self->_queue, invocation);
   }
}


static void   MulleInvocationQueueFinalPush( MulleInvocationQueue *self,
                                             NSInvocation *invocation)
{
   mulle_thread_mutex_do( self->_queueLock)
   {
      [invocation retainArguments];
      [invocation retain];
      self->_finalInvocation = invocation;

      [invocation mulleRelinquishAccess];
      mulle_pointerqueue_push( &self->_queue, invocation);
   }
}


static NSInvocation  *MulleInvocationQueuePop( MulleInvocationQueue *self,
                                               BOOL *isFinal)
{
   NSInvocation   *invocation;

   mulle_thread_mutex_do( self->_queueLock)
   {
      invocation = mulle_pointerqueue_pop( &self->_queue);
      [invocation mulleGainAccess];
      [invocation autorelease];

      if( isFinal)
         *isFinal = (invocation == self->_finalInvocation);
   }
   return( invocation);
}


static void   MulleInvocationQueueDiscardInvocations( MulleInvocationQueue *self)
{
   NSInvocation   *invocation;

   mulle_thread_mutex_do( self->_queueLock)
   {
      while( (invocation = mulle_pointerqueue_pop( &self->_queue)))
         [invocation autorelease];
   }
}


static void   MulleInvocationQueueFinalizing( MulleInvocationQueue *self)
{
   mulle_thread_mutex_do( self->_queueLock)
   {
      self->_finalInvocation = nil;
   }
}



+ (instancetype) invocationQueue
{
   return( [[[self alloc] initWithCapacity:128
                             configuration:0] autorelease]);
}


- (instancetype) initWithCapacity:(NSUInteger) capacity
                    configuration:(MulleInvocationQueueConfiguration) configuration
{
   mulle_thread_mutex_init( &_queueLock);
   mulle_pointerqueue_init( &_queue, capacity / 8, 8, MulleObjCInstanceGetAllocator( self));
   _configuration = configuration;

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
   MulleInvocationQueueDiscardInvocations( self);
   MulleInvocationQueueFinalizing( self);

   [super finalize];
}


- (void) dealloc
{
   NSInvocation   *invocation;

   assert( ! _failedInvocation);
   [_executionThread release];
   [_exception release];

   mulle_thread_mutex_done( &_queueLock);

   // safety..., no need to lock though
   while( (invocation = mulle_pointerqueue_pop( &_queue)))
      [invocation release];
   mulle_pointerqueue_done( &_queue);

   [super dealloc];
}

// @property accessors

- (BOOL) trace
{
   return( (_configuration & MulleInvocationQueueTrace) ? YES : NO);
}


- (BOOL) doneOnEmptyQueue
{
   return( (_configuration & MulleInvocationQueueDoneOnEmptyQueue) ? YES : NO);
}


- (BOOL) catchesExceptions
{
   return( (_configuration & MulleInvocationQueueCatchesExceptions) ? YES : NO);
}


- (BOOL) ignoresCaughtExceptions
{
   return( (_configuration & MulleInvocationQueueIgnoresCaughtExceptions) ? YES : NO);
}


- (BOOL) cancelsOnFailedReturnStatus
{
   return( (_configuration & MulleInvocationQueueCancelsOnFailedReturnStatus) ? YES : NO);
}


- (BOOL) messageDelegateOnExecutionThread
{
   return( (_configuration & MulleInvocationQueueMessageDelegateOnExecutionThread) ? YES : NO);
}


- (BOOL) terminateWaitsForCompletion
{
   return( (_configuration & MulleInvocationQueueTerminateWaitsForCompletion) ? YES : NO);
}



- (BOOL) isExecutionThread
{
   return( ! _executionThread || [NSThread currentThread] == _executionThread);
}


- (NSUInteger) state
{
   NSUInteger   state;

   state = (NSUInteger) _mulle_atomic_pointer_read( &_state);
   if( _configuration & MulleInvocationQueueTrace)
      fprintf( stderr, "queue %p state is %s\n", self, MulleInvocationQueueStateUTF8String( state));
   return( state);
}


- (void) _setState:(NSUInteger) state     MULLE_OBJC_THREADSAFE_METHOD
{
   void   *expect;

   _mulle_atomic_pointer_write( &_state, (void *) state);

   if( (_configuration & MulleInvocationQueueMessageDelegateOnExecutionThread) &&
       [self isExecutionThread])
   {
      [_delegate invocationQueueDidChangeState:self];
      do
      {
         expect = _mulle_atomic_pointer_read( &_state);
         state  = (NSUInteger) expect | MulleInvocationQueueNotified;
      }
      while( ! _mulle_atomic_pointer_cas( &_state, (void *) state, expect));
   }
}


- (NSUInteger) numberOfInvocations
{
   NSUInteger   count;

   mulle_thread_mutex_do( self->_queueLock)
   {
      count = mulle_pointerqueue_get_count( &_queue);
   }
   return( count);
}


- (void) addInvocation:(NSInvocation *) invocation
{
   MulleInvocationQueuePush( self, invocation);

   [_executionThread nudge];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   MulleInvocationQueueFinalPush( self, invocation);

   [_executionThread nudge];
}


- (int) invokeNextInvocation:(id) unused
{
   NSInvocation   *invocation;
   BOOL           isFinal;

   assert( [self isExecutionThread]);

   invocation = MulleInvocationQueuePop( self, &isFinal);
   if( ! invocation)
   {
      if( _configuration & MulleInvocationQueueDoneOnEmptyQueue)
      {
         MulleInvocationQueueFinalizing( self);   // do this before _setState:
         [self _setState:MulleInvocationQueueDone];
         return( MulleThreadGoIdle);
      }
      [self _setState:MulleInvocationQueueEmpty];
      return( MulleThreadGoIdle);
   }

   [self _setState:MulleInvocationQueueRun];

   if( _configuration & MulleInvocationQueueTrace)
      fprintf( stderr, "queue %p executes %s", self, [invocation invocationUTF8String]);

   if( _configuration & MulleInvocationQueueIgnoresCaughtExceptions)
   {
      @try
      {
         [invocation invoke];
      }
      @catch( NSObject *exception)
      {
         if( (_configuration & MulleInvocationQueueIgnoresCaughtExceptions))
            return( MulleThreadContinueMain);

         [_exception autorelease];
         _exception = [exception retain];

         MulleInvocationQueueDiscardInvocations( self);
         [self _setState:MulleInvocationQueueException];
         return( MulleThreadCancelMain);
      }
   }
   else
   {
      [invocation invoke];
   }

   if( (_configuration & MulleInvocationQueueCancelsOnFailedReturnStatus) &&
       [invocation mulleReturnStatus])
   {
      MulleInvocationQueueDiscardInvocations( self);
      [self _setState:MulleInvocationQueueError];
      return( MulleThreadCancelMain);
   }

   if( isFinal)
   {
      [self _setState:MulleInvocationQueueDone];
      MulleInvocationQueueFinalizing( self);   // do this *after* _setState:
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

      // this is the only time _executionThread must be written to before
      // finalize/dealloc
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

   if( ! _executionThread)
      return;

   assert( [NSThread currentThread] != _executionThread);

   for(;;)
   {
      state = [self state];
      switch( state & ~MulleInvocationQueueNotified)
      {
      case MulleInvocationQueueInit      :
         [_executionThread nudge]; // ????
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

   if( _configuration & MulleInvocationQueueTerminateWaitsForCompletion)
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
      if( ! (_configuration & MulleInvocationQueueMessageDelegateOnExecutionThread) &&
          ! [self isExecutionThread])
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
