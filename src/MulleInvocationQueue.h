#ifdef __has_include
# if __has_include( "NSObject.h")
#  import "NSObject.h"
# endif
#endif

#import "import.h"

#define MULLE_INVOCATION_QUEUE_VERSION ((0 << 20) | (0 << 8) | 3)


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
   MulleInvocationQueueNotified = 0x8000          // "main" has notified
};


MULLE_INVOCATION_QUEUE_GLOBAL
NS_OPTIONS_TABLE( MulleInvocationQueueState, 9);


static inline char   *MulleInvocationQueueStateUTF8String( NSUInteger options)
{
   return( NS_OPTIONS_PRINT( MulleInvocationQueueState, options));
}


static inline BOOL   MulleInvocationQueueStateIsFinished( NSUInteger state)
{
   state &= ~MulleInvocationQueueNotified;
   switch( state)
   {
   default                            : return( NO);
   case MulleInvocationQueueEmpty     :
   case MulleInvocationQueueCancel    :
   case MulleInvocationQueueException :
   case MulleInvocationQueueDone      : return( YES);
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
- (void) invocationQueueDidChangeState:(MulleInvocationQueue *) queue;

@end


//
// TODO: check for invocations pushing things unto the same invocation queue
//

@interface MulleInvocationQueue : NSObject
{
   mulle_thread_mutex_t                _queueLock;
   struct mulle_pointerqueue           _queue;
   mulle_atomic_pointer_t              _state;
   NSInvocation                        *_finalInvocation;  // assign! (retained via _queue logic)
   MulleInvocationQueueConfiguration   _configuration;
}

@property( assign) id <MulleInvocationQueueDelegate>   delegate;

@property( readonly, retain) MulleThread               *executionThread;
@property( readonly, retain) NSInvocation              *failedInvocation;
@property( readonly, retain) id                        exception;

@property( readonly, dynamic) BOOL   trace                            MULLE_OBJC_THREADSAFE_PROPERTY;                            // send "done", whenever queue is empty (NO)
@property( readonly, dynamic) BOOL   doneOnEmptyQueue                 MULLE_OBJC_THREADSAFE_PROPERTY;                 // send "done", whenever queue is empty (NO)
@property( readonly, dynamic) BOOL   catchesExceptions                MULLE_OBJC_THREADSAFE_PROPERTY;                // cancel on exception (NO)
@property( readonly, dynamic) BOOL   ignoresCaughtExceptions          MULLE_OBJC_THREADSAFE_PROPERTY;          // (NO)
@property( readonly, dynamic) BOOL   cancelsOnFailedReturnStatus      MULLE_OBJC_THREADSAFE_PROPERTY;      // (NO)
@property( readonly, dynamic) BOOL   messageDelegateOnExecutionThread MULLE_OBJC_THREADSAFE_PROPERTY; // (NO)
@property( readonly, dynamic) BOOL   terminateWaitsForCompletion      MULLE_OBJC_THREADSAFE_PROPERTY;      // don't terminate before complete (NO)


+ (instancetype) invocationQueue;
- (instancetype) initWithCapacity:(NSUInteger) capacity
                    configuration:(MulleInvocationQueueConfiguration) configuration;

- (BOOL) poll;
- (int) invokeNextInvocation:(id) sender                    MULLE_OBJC_THREADSAFE_METHOD;  // unused sender

// calls cancel if not appShouldWaitForCompletion, else blocks
- (int) terminate                                           MULLE_OBJC_THREADSAFE_METHOD;
- (void) preempt                                            MULLE_OBJC_THREADSAFE_METHOD;
- (void) cancelWhenIdle                                     MULLE_OBJC_THREADSAFE_METHOD;
- (void) start                                              MULLE_OBJC_THREADSAFE_METHOD;

- (void) addInvocation:(NSInvocation *) invocation          MULLE_OBJC_THREADSAFE_METHOD;
- (void) addFinalInvocation:(NSInvocation *) invocation     MULLE_OBJC_THREADSAFE_METHOD;

- (NSUInteger) state                                        MULLE_OBJC_THREADSAFE_METHOD;


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
