#ifdef __has_include
# if __has_include( "NSObject.h")
#  import "NSObject.h"
# endif
#endif

#import "import.h"

#define MULLE_INVOCATION_QUEUE_VERSION ((0UL << 20) | (1 << 8) | 0)


@class MulleThread;
@class MulleInvocationQueue;



typedef NS_OPTIONS( NSUInteger, MulleInvocationQueueConfiguration)
{
   MulleInvocationQueueTrace                            = 0x1,
   MulleInvocationQueueDoneOnEmptyQueue                 = 0x2,  // send "done", whenever queue is empty (NO)
   MulleInvocationQueueCatchesExceptions                = 0x4,  // cancel on exception (NO)
   MulleInvocationQueueIgnoresCaughtExceptions          = 0x8,  // (NO)
   MulleInvocationQueueCancelsOnFailedReturnStatus      = 0x10, // (NO)
   MulleInvocationQueueMessageDelegateOnExecutionThread = 0x20, // (NO)
   MulleInvocationQueueTerminateWaitsForCompletion      = 0x40
};


typedef NS_OPTIONS( NSUInteger, MulleInvocationQueueState)
{
   MulleInvocationQueueInit = 0,                  // in the beginning
   MulleInvocationQueueIdle,                      // when empty
   MulleInvocationQueueRun,                       // queue is executing
   MulleInvocationQueueEmpty,                     // all invocations processed
   MulleInvocationQueueDone,                      // all invocations till final processed
   MulleInvocationQueueError,                     // cancel request fulfilled by "execution"
   MulleInvocationQueueException,
   MulleInvocationQueueCancel,
   MulleInvocationQueueTerminated,                // no longer usable
   MulleInvocationQueueNotified = 0x8000          // "main" has notified
};


MULLE_INVOCATION_QUEUE_GLOBAL
NS_OPTIONS_TABLE( MulleInvocationQueueState, 10);


static inline char   *MulleInvocationQueueStateUTF8String( NSUInteger options)
{
   return( NS_OPTIONS_PRINT( MulleInvocationQueueState, options));
}


static inline BOOL   MulleInvocationQueueStateIsFinished( NSUInteger state)
{
   state &= ~MulleInvocationQueueNotified;
   switch( state)
   {
   default                             : return( NO);
   case MulleInvocationQueueEmpty      :
   case MulleInvocationQueueCancel     :
   case MulleInvocationQueueException  :
   case MulleInvocationQueueTerminated :
   case MulleInvocationQueueDone       : return( YES);
   }
}

static inline BOOL   MulleInvocationQueueStateCanBeCancelled( NSUInteger state)
{
   state &= ~MulleInvocationQueueNotified;
   switch( state)
   {
   default                            : return( NO);
   case MulleInvocationQueueIdle      :
   case MulleInvocationQueueCancel    :
   case MulleInvocationQueueException :
   case MulleInvocationQueueEmpty     :
   case MulleInvocationQueueDone      : return( YES);
   }
}



@protocol MulleInvocationQueueDelegate

// check state
- (void) invocationQueue:(MulleInvocationQueue *) queue
        didChangeToState:(NSUInteger) state;

@end


#define MULLE_INVOCATION_QUEUE_EXECUTION_THREAD_ONLY  MULLE_OBJC_THREADSAFE_METHOD
#define MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY  MULLE_OBJC_THREADSAFE_METHOD

//
// TODO: check for invocations pushing things unto the same invocation queue
//
//       In this plain state, the MulleInvocationQueue will not be usable with
//       targets that are non threadsafe (or you can only queue a single
//       invocation for each target). That somewhat defeats the purpose of
//       an invocationQueue for use with an NSFileHandle for example, where
//       you want to output blocks in several queue steps. But the NSFileHandle
//       is not threadsafe and therefore the first invocation will bind it to
//       the execution thread, and a second invocation will bring misery.
//       Solution: Use the MulleSingleTargetInvocationQueue, which fixes this
//       problem.
//
@interface MulleInvocationQueue : NSObject
{
   mulle_thread_mutex_t                _queueLock;
   struct mulle_pointerqueue           _queue;
   mulle_atomic_pointer_t              _atomic_state;
   mulle_atomic_pointer_t              _executionThread;
   NSInvocation                        *_finalInvocation;  // assign! (retained via _queue logic)
   MulleInvocationQueueConfiguration   _configuration;
   mulle_absolutetime_t                _startTime;
}

@property( assign) id <MulleInvocationQueueDelegate>   delegate;

@property( readonly, dynamic, retain) MulleThread      *executionThread;
@property( readonly, retain) NSInvocation              *failedInvocation;
@property( readonly, retain) id                        exception;

@property( readonly, dynamic) BOOL   trace; // send "done", whenever queue is empty (NO)
@property( readonly, dynamic) BOOL   doneOnEmptyQueue; // send "done", whenever queue is empty (NO)
@property( readonly, dynamic) BOOL   catchesExceptions; // cancel on exception (NO)
@property( readonly, dynamic) BOOL   ignoresCaughtExceptions; // (NO)
@property( readonly, dynamic) BOOL   cancelsOnFailedReturnStatus; // (NO)
@property( readonly, dynamic) BOOL   messageDelegateOnExecutionThread; // (NO)
@property( readonly, dynamic) BOOL   terminateWaitsForCompletion; // don't terminate before complete (NO)

@property( readonly, dynamic) NSUInteger      state; // don't terminate before complete (NO)


+ (instancetype) invocationQueue;
+ (instancetype) invocationQueueWithCapacity:(NSUInteger) capacity
                               configuration:(MulleInvocationQueueConfiguration) configuration;
- (instancetype) initWithCapacity:(NSUInteger) capacity
                    configuration:(MulleInvocationQueueConfiguration) configuration;

//
// calls cancel if not appShouldWaitForCompletion, else blocks
// the delegate will be nil after a succesful call
// 0: OK
// -1: fail (no thread running)
//
- (int) terminate                                           MULLE_OBJC_THREADSAFE_METHOD;
- (void) preempt                                            MULLE_OBJC_THREADSAFE_METHOD;

// can not be called from the execution thread
- (void) cancelWhenIdle                                     MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY;
- (void) start                                              MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY;

// same as start, but use a subclass of MulleThread
- (void) startWithThreadClass:(Class) threadClass           MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY;

- (void) addInvocation:(NSInvocation *) invocation          MULLE_OBJC_THREADSAFE_METHOD;
- (void) addFinalInvocation:(NSInvocation *) invocation     MULLE_OBJC_THREADSAFE_METHOD;


//
// method **not** to be used by the executionThread and code that is "inside"
// the invocations
//
- (BOOL) poll                                               MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY;

// only useful for testing, as this runs the MulleInvocationQueue synchronously
- (int) invokeNextInvocation:(id) sender                    MULLE_OBJC_THREADSAFE_METHOD;  // unused sender



@end


#import "_MulleInvocationQueue-export.h"


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
