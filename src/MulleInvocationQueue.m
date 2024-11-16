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


NS_OPTIONS_TABLE( MulleInvocationQueueState, 10) =
{
   NS_OPTIONS_ITEM( MulleInvocationQueueInit),
   NS_OPTIONS_ITEM( MulleInvocationQueueIdle),
   NS_OPTIONS_ITEM( MulleInvocationQueueRun),
   NS_OPTIONS_ITEM( MulleInvocationQueueEmpty),
   NS_OPTIONS_ITEM( MulleInvocationQueueDone),
   NS_OPTIONS_ITEM( MulleInvocationQueueError),
   NS_OPTIONS_ITEM( MulleInvocationQueueException),
   NS_OPTIONS_ITEM( MulleInvocationQueueCancel),
   NS_OPTIONS_ITEM( MulleInvocationQueueTerminated),
   NS_OPTIONS_ITEM( MulleInvocationQueueNotified)
};


@implementation MulleInvocationQueue


static void   _MulleInvocationQueuePush( MulleInvocationQueue *self,
                                         NSInvocation *invocation)
{
   [invocation retainArguments];
   [invocation retain];

   [invocation mulleRelinquishAccess];
   mulle_pointerqueue_push( &self->_queue, invocation);
}


static void   MulleInvocationQueuePush( MulleInvocationQueue *self,
                                        NSInvocation *invocation)
{
   mulle_thread_mutex_do( self->_queueLock)
   {
      _MulleInvocationQueuePush( self, invocation);
      assert( ! self->_finalInvocation);
   }
}


static void   MulleInvocationQueueFinalPush( MulleInvocationQueue *self,
                                             NSInvocation *invocation)
{
   mulle_thread_mutex_do( self->_queueLock)
   {
      _MulleInvocationQueuePush( self, invocation);
      assert( ! self->_finalInvocation);
      self->_finalInvocation = invocation;
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
      self->_finalInvocation = nil;
   }
   return( invocation);
}


static void   MulleInvocationQueueDiscardInvocations( MulleInvocationQueue *self)
{
   NSInvocation   *invocation;

   mulle_thread_mutex_do( self->_queueLock)
   {
      while( (invocation = mulle_pointerqueue_pop( &self->_queue)))
      {
         // gainAccess will autorelease the invocation into the current
         // thread, but is this really needed ?
         [invocation mulleGainAccess];
         [invocation autorelease];
      }
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
   return( [[[self alloc] initWithCapacity:0
                             configuration:0] autorelease]);
}


- (instancetype) initWithCapacity:(NSUInteger) capacity
                    configuration:(MulleInvocationQueueConfiguration) configuration
{
   if( ! capacity)
      capacity = 128;
   mulle_thread_mutex_init( &_queueLock);
   mulle_pointerqueue_init( &_queue, capacity / 8, 8, MulleObjCInstanceGetAllocator( self));
   _configuration = configuration;

   return( self);
}


+ (instancetype) invocationQueueWithCapacity:(NSUInteger) capacity
                               configuration:(MulleInvocationQueueConfiguration) configuration
{
   MulleInvocationQueue   *queue;

   queue = [self alloc];
   queue = [queue initWithCapacity:capacity
                     configuration:configuration];
   queue = [queue autorelease];
   return( queue);
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
   MulleThread    *executionThread;

   assert( ! _failedInvocation);

   executionThread = (MulleThread *) _mulle_atomic_pointer_read_nonatomic( &_executionThread);
   [executionThread release];
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


- (BOOL) isExecutionThread       MULLE_OBJC_THREADSAFE_METHOD
{
   MulleThread   *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   return( ! executionThread || [NSThread currentThread] == executionThread);
}


- (NSUInteger) state
{
   NSUInteger   state;

   state = (NSUInteger) _mulle_atomic_pointer_read( &_atomic_state);
   if( _configuration & MulleInvocationQueueTrace)
      fprintf( stderr, "queue %p state is %s\n", self, MulleInvocationQueueStateUTF8String( state));
   return( state);
}


- (void) _setState:(NSUInteger) state     MULLE_OBJC_THREADSAFE_METHOD
{
   assert( (NSUInteger) _mulle_atomic_pointer_read( &_atomic_state) != state);

   _mulle_atomic_pointer_write( &_atomic_state, (void *) state);
   if( (_configuration & MulleInvocationQueueMessageDelegateOnExecutionThread) &&
       [self isExecutionThread])
   {
      [_delegate invocationQueue:self
                didChangeToState:state];
      _mulle_atomic_pointer_write( &_atomic_state, (void *) (state | MulleInvocationQueueNotified));
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
   MulleThread   *executionThread;

   MulleInvocationQueuePush( self, invocation);

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   [executionThread nudge];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   MulleThread   *executionThread;

   MulleInvocationQueueFinalPush( self, invocation);

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   [executionThread nudge];
}


- (NSInvocation *) popInvocation:(BOOL *) isFinal
{
   return( MulleInvocationQueuePop( self, isFinal));
}


- (void) didInvokeFinalInvocation:(NSInvocation *) invocation
{
   MulleInvocationQueueFinalizing( self);   // do this *after* _setState:
}


- (int) invokeNextInvocation:(id) unused
{
   NSInvocation   *invocation;
   BOOL           isFinal;

   assert( [self isExecutionThread]);

   invocation = [self popInvocation:&isFinal];
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
      [self didInvokeFinalInvocation:invocation]; // do this *after* _setState:
      return( MulleThreadCancelMain);
   }

   return( MulleThreadContinueMain);
}


- (void) startWithThreadClass:(Class) mulleThreadSubclass
{
   NSInvocation   *invocation;
   Class          mulleThreadClass;
   MulleThread    *executionThread;

   mulleThreadClass = [MulleThread class];
   if( ! mulleThreadSubclass)
      mulleThreadSubclass = mulleThreadClass;
   assert( [self state] != MulleInvocationQueueTerminated);

retry:
   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   if( ! executionThread)
   {
      // this is the only time _executionThread must be written to before
      // finalize/dealloc
      //
      // TODO: shouldn't there be a loop around invokeNextInvocation: ???
      //
      invocation = [NSInvocation mulleInvocationWithTarget:self
                                                  selector:@selector( invokeNextInvocation:)
                                                    object:nil];
      // do not retain self here as it would create a cycle
      executionThread = [[mulleThreadSubclass alloc] mulleInitWithInvocation:invocation];
      [executionThread mulleSetNameUTF8String:"MulleInvocationQueueThread"];
      if( ! _mulle_atomic_pointer_cas( &_executionThread, executionThread, NULL))
      {
         [executionThread autorelease];
         goto retry;
      }
   }

   assert( [executionThread isKindOfClass:mulleThreadSubclass]);

   _startTime = mulle_absolutetime_now();
   [executionThread mulleStart];
}


- (void) start
{
   [self startWithThreadClass:Nil];
}


- (void) preempt
{
   MulleThread    *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   [executionThread preempt];
   [executionThread mulleJoin];
}


- (void) cancelWhenIdle
{
   NSUInteger    state;
   MulleThread   *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   if( ! executionThread)
   {
      // if the executionThread never ran, reclaim invocations for
      // caller thread
      MulleInvocationQueueDiscardInvocations( self);
      return;
   }

   assert( [NSThread currentThread] != executionThread);

   for(;;)
   {
      state = [self state] & ~MulleInvocationQueueNotified;
      switch( state)
      {
      case MulleInvocationQueueInit      :
         [executionThread nudge]; // ????
         break;

      case MulleInvocationQueueRun       :
         break;

      case MulleInvocationQueueIdle      :
      case MulleInvocationQueueEmpty     :
      case MulleInvocationQueueDone      :
      case MulleInvocationQueueError     :
      case MulleInvocationQueueException :
      case MulleInvocationQueueCancel    :
         [executionThread cancelWhenIdle];
         [executionThread mulleJoin];
         return;

      case MulleInvocationQueueTerminated :
         assert( 0 || "cancelWhenIdle called on a already terminated queue");
         return;
      }
      [executionThread blockUntilNoLongerBusy];
   }
}


- (int) terminate
{
   MulleThread   *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   if( ! executionThread)
      return( -1);

   if( _configuration & MulleInvocationQueueTerminateWaitsForCompletion)
      [self cancelWhenIdle];
   else
      [executionThread preempt];
      // get execution thread to release invocation
   [executionThread mulleJoin];

   [executionThread autorelease];
   _mulle_atomic_pointer_write( &_executionThread, NULL);

   // this could be owned by the thread exclusively, so we nil it
   // to not send another message
   _delegate = nil;

   // conceivably you could reuse the queue, but why ?
   [self _setState:MulleInvocationQueueTerminated];

   return( 0);
}


// the executionThread most likely need not be atomic, this is just
// conservatism here, which shouldn't really hurt
- (MulleThread *) executionThread
{
   MulleThread   *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   return( executionThread);
}


// returns 1 if running
- (BOOL) poll
{
   NSUInteger     state;
   MulleThread    *executionThread;

   executionThread = (MulleThread *) _mulle_atomic_pointer_read( &_executionThread);
   assert( [NSThread currentThread] != executionThread);

   state = [self state];
   if( ! (state & MulleInvocationQueueNotified))
   {
      if( ! (_configuration & MulleInvocationQueueMessageDelegateOnExecutionThread) &&
          ! [self isExecutionThread])
      {
         [self _setState:state | MulleInvocationQueueNotified];
         [_delegate invocationQueue:self
                   didChangeToState:state];
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
