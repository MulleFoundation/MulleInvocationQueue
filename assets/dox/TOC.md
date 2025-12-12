# MulleInvocationQueue Library Documentation for AI

## 1. Introduction & Purpose

MulleInvocationQueue provides asynchronous method invocation processing in a dedicated thread. Accepts NSInvocation objects queued from the main thread and executes them serially in a background worker thread with automatic error handling, exception catching, and state notifications. Enables safe off-main-thread task processing with optional delegate callbacks for state changes and completion handling.

## 2. Key Concepts & Design Philosophy

- **Asynchronous Processing**: Queue methods from main thread; execute serially in background
- **Thread-Safe Queueing**: Add invocations from any thread; executes sequentially
- **Invocation-Based**: Uses NSInvocation for flexible method dispatch
- **State Machine**: Tracks queue state (Init, Idle, Run, Empty, Done, Error, Exception, Cancelled)
- **Exception Handling**: Optional exception catching and continuation
- **Delegate Notifications**: State change notifications via delegate pattern
- **Final Invocation**: Support for cleanup/finalization invocation
- **Configuration Options**: Fine-grained control over error handling and notification

## 3. Core API & Data Structures

### Configuration Options

```objc
typedef NS_OPTIONS(NSUInteger, MulleInvocationQueueConfiguration) {
    MulleInvocationQueueTrace                            = 0x1,    // Enable tracing
    MulleInvocationQueueDoneOnEmptyQueue                 = 0x2,    // Notify done when empty
    MulleInvocationQueueCatchesExceptions                = 0x4,    // Catch & handle exceptions
    MulleInvocationQueueIgnoresCaughtExceptions          = 0x8,    // Ignore caught exceptions
    MulleInvocationQueueCancelsOnFailedReturnStatus      = 0x10,   // Cancel on return error
    MulleInvocationQueueMessageDelegateOnExecutionThread = 0x20,   // Notify delegate on exec thread
    MulleInvocationQueueTerminateWaitsForCompletion      = 0x40    // Wait for completion on terminate
};
```

### State Machine

```objc
typedef NS_OPTIONS(NSUInteger, MulleInvocationQueueState) {
    MulleInvocationQueueInit        = 0,       // Initial state before start
    MulleInvocationQueueIdle,                  // Queue empty, waiting for invocations
    MulleInvocationQueueRun,                   // Queue executing invocation
    MulleInvocationQueueEmpty,                 // All invocations processed
    MulleInvocationQueueDone,                  // Final invocation processed
    MulleInvocationQueueError,                 // Cancelled due to error
    MulleInvocationQueueException,             // Cancelled due to exception
    MulleInvocationQueueCancel,                // Manual cancellation
    MulleInvocationQueueTerminated,            // Queue terminated, no longer usable
    MulleInvocationQueueNotified = 0x8000      // Main thread has been notified
};
```

### Creation & Initialization

- `+ invocationQueue` → `instancetype`: Create default queue
- `+ invocationQueueWithCapacity:(NSUInteger)capacity configuration:(MulleInvocationQueueConfiguration)config` → `instancetype`: Create with specific capacity and config
- `- initWithCapacity:(NSUInteger)capacity configuration:(MulleInvocationQueueConfiguration)config` → `instancetype`: Initialize queue

### Queue Control

- `- start` → `void`: Start background thread (not from exec thread)
- `- startWithThreadClass:(Class)threadClass` → `void`: Start with custom MulleThread subclass
- `- addInvocation:(NSInvocation *)inv` → `void`: Add regular invocation (thread-safe)
- `- addFinalInvocation:(NSInvocation *)inv` → `void`: Add final/cleanup invocation (thread-safe)
- `- cancelWhenIdle` → `void`: Cancel gracefully at next idle point (not from exec thread)
- `- preempt` → `void`: Cancel immediately (thread-safe)
- `- terminate` → `int`: Terminate queue; returns 0 on success, -1 on failure (thread-safe)
- `- poll` → `BOOL`: Check/poll queue without blocking (not from exec thread)
- `- invokeNextInvocation:(id)sender` → `int`: Synchronously invoke next (testing only)

### Properties

- `delegate` (id<MulleInvocationQueueDelegate>, assign): Delegate for state notifications
- `executionThread` (MulleThread *, readonly, retain): Background execution thread
- `failedInvocation` (NSInvocation *, readonly, retain): Invocation that caused error
- `exception` (id, readonly, retain): Exception caught during execution
- `state` (NSUInteger, readonly, dynamic): Current queue state
- `trace` (BOOL, readonly, dynamic): Whether tracing enabled
- `doneOnEmptyQueue` (BOOL, readonly, dynamic): Notify when queue becomes empty
- `catchesExceptions` (BOOL, readonly, dynamic): Whether exceptions are caught
- `ignoresCaughtExceptions` (BOOL, readonly, dynamic): Ignore caught exceptions
- `cancelsOnFailedReturnStatus` (BOOL, readonly, dynamic): Cancel on invocation return error
- `messageDelegateOnExecutionThread` (BOOL, readonly, dynamic): Send delegate messages on exec thread
- `terminateWaitsForCompletion` (BOOL, readonly, dynamic): Block terminate until complete

### Delegate Protocol

```objc
@protocol MulleInvocationQueueDelegate
- (void) invocationQueue:(MulleInvocationQueue *)queue 
          didChangeToState:(NSUInteger)state;
@end
```

Delegate callback fired when queue state changes (if messageDelegateOnExecutionThread, called on background thread).

### State Helper Functions

- `MulleInvocationQueueStateIsFinished(NSUInteger state)` → `BOOL`: Check if state is terminal
- `MulleInvocationQueueStateCanBeCancelled(NSUInteger state)` → `BOOL`: Check if state allows cancellation
- `MulleInvocationQueueStateUTF8String(NSUInteger state)` → `char *`: Get state name as C string

### Return Status Protocol

Invocations can return status codes:
- `MulleInvocationReturnStatusOK` (0): Continue normally
- `MulleInvocationReturnStatusFailed` (-1): Error condition (cancels if configured)
- `MulleInvocationReturnStatusCancel` (-2): Cancel queue

## 4. Performance Characteristics

- **Queueing**: O(1) lock-based queue insertion (thread-safe)
- **Execution**: O(1) per invocation dispatch (excluding invocation body)
- **Threading**: One background thread per queue (minimal overhead)
- **Synchronization**: Mutex-based locking; efficient on multi-core
- **Memory**: Queue grows with pending invocations; configurable capacity
- **Latency**: Background thread processes immediately when nudged
- **Contention**: Low; main thread only locks during add operations

## 5. AI Usage Recommendations & Patterns

### Best Practices

- **Queue from Main Thread**: Add invocations from main thread; execute in background
- **Thread-Safe Target**: Target objects must be thread-safe or exclusively used by queue
- **Final Invocation**: Use final invocation for cleanup (close files, flush buffers)
- **Exception Handling**: Enable exception catching for robustness
- **Delegate Callbacks**: Set delegate to monitor progress
- **Graceful Shutdown**: Use cancelWhenIdle + terminate for clean shutdown
- **Return Status**: Have invocations return status codes for error detection

### Common Pitfalls

- **From Exec Thread**: Never call start, cancelWhenIdle, or poll from execution thread
- **Thread Safety**: Target must handle concurrent access if reused by queue
- **Memory Cycles**: Invocations hold references; ensure no cycles with queue
- **Exceptions**: Uncaught exceptions crash unless exception catching enabled
- **Delegate Deadlock**: Delegate on exec thread may deadlock if blocking on main thread
- **Multiple Adds**: Can queue multiple invocations for same target (if target thread-safe)
- **Terminate Blocking**: Terminate waits if terminateWaitsForCompletion set

### Idiomatic Usage

```objc
// Pattern 1: Create and queue work
MulleInvocationQueue *queue = [MulleInvocationQueue invocationQueue];
[queue start];

NSInvocation *inv = [NSInvocation mulleInvocationWithTarget:target
                                                   selector:@selector(doWork:)
                                                      args:data];
[queue addInvocation:inv];

// Pattern 2: Set delegate for state monitoring
@interface Monitor : NSObject <MulleInvocationQueueDelegate> @end
@implementation Monitor
- (void)invocationQueue:(MulleInvocationQueue *)q didChangeToState:(NSUInteger)s {
    NSLog(@"State changed to: %s", MulleInvocationQueueStateUTF8String(s));
}
@end

queue.delegate = [[[Monitor alloc] init] autorelease];

// Pattern 3: Graceful shutdown
[queue cancelWhenIdle];
[queue terminate];

// Pattern 4: Final invocation for cleanup
NSInvocation *cleanup = [NSInvocation mulleInvocationWithTarget:resource
                                                        selector:@selector(close)];
[queue addFinalInvocation:cleanup];
```

## 6. Integration Examples

### Example 1: Basic Queue Usage

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface Worker : NSObject
- (void)doWork:(NSString *)task;
@end

@implementation Worker
- (void)doWork:(NSString *)task {
    NSLog(@"Processing: %@", task);
}
@end

int main() {
    Worker *worker = [[Worker alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue invocationQueue];
    [queue start];
    
    // Queue some work
    for (int i = 0; i < 3; i++) {
        NSString *task = [NSString stringWithFormat:@"Task%d", i];
        NSInvocation *inv = [NSInvocation mulleInvocationWithTarget:worker
                                                          selector:@selector(doWork:)
                                                            objects:task];
        [queue addInvocation:inv];
    }
    
    sleep(2);
    
    [queue cancelWhenIdle];
    [queue terminate];
    [worker release];
    
    return 0;
}
```

### Example 2: Queue with Delegate Monitoring

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface QueueMonitor : NSObject <MulleInvocationQueueDelegate>
@end

@implementation QueueMonitor
- (void)invocationQueue:(MulleInvocationQueue *)queue
        didChangeToState:(NSUInteger)state {
    NSLog(@"Queue state: %s", MulleInvocationQueueStateUTF8String(state));
}
@end

@interface Task : NSObject
- (void)execute:(NSString *)name;
@end

@implementation Task
- (void)execute:(NSString *)name {
    NSLog(@"Executing: %@", name);
    sleep(1);
}
@end

int main() {
    Task *task = [[Task alloc] init];
    QueueMonitor *monitor = [[QueueMonitor alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue 
        invocationQueueWithCapacity:16
                      configuration:MulleInvocationQueueDoneOnEmptyQueue];
    
    queue.delegate = monitor;
    [queue start];
    
    NSInvocation *inv = [NSInvocation mulleInvocationWithTarget:task
                                                       selector:@selector(execute:)
                                                        objects:@"Work"];
    [queue addInvocation:inv];
    
    sleep(3);
    
    [queue terminate];
    [task release];
    [monitor release];
    
    return 0;
}
```

### Example 3: Exception Handling

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface RiskyWork : NSObject
- (void)mayThrow;
- (void)alsoWorks;
@end

@implementation RiskyWork
- (void)mayThrow {
    NSException *ex = [NSException exceptionWithName:@"TestException"
                                              reason:@"Intentional"
                                            userInfo:nil];
    [ex raise];
}

- (void)alsoWorks {
    NSLog(@"This still runs despite previous exception");
}
@end

int main() {
    RiskyWork *work = [[RiskyWork alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue 
        invocationQueueWithCapacity:16
                      configuration:MulleInvocationQueueCatchesExceptions];
    
    [queue start];
    
    // Queue throws
    NSInvocation *inv1 = [NSInvocation mulleInvocationWithTarget:work
                                                        selector:@selector(mayThrow)];
    [queue addInvocation:inv1];
    
    // Queue continues despite exception
    NSInvocation *inv2 = [NSInvocation mulleInvocationWithTarget:work
                                                        selector:@selector(alsoWorks)];
    [queue addInvocation:inv2];
    
    sleep(2);
    
    [queue cancelWhenIdle];
    [queue terminate];
    [work release];
    
    return 0;
}
```

### Example 4: Return Status Error Handling

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface StatusfulWork : NSObject
- (int)successfulTask;
- (int)failingTask;
@end

@implementation StatusfulWork
- (int)successfulTask {
    NSLog(@"Task succeeded");
    return MulleInvocationReturnStatusOK;
}

- (int)failingTask {
    NSLog(@"Task failed");
    return MulleInvocationReturnStatusFailed;
}
@end

int main() {
    StatusfulWork *work = [[StatusfulWork alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue 
        invocationQueueWithCapacity:16
                      configuration:MulleInvocationQueueCancelsOnFailedReturnStatus];
    
    [queue start];
    
    NSInvocation *inv1 = [NSInvocation mulleInvocationWithTarget:work
                                                        selector:@selector(successfulTask)];
    [queue addInvocation:inv1];
    
    NSInvocation *inv2 = [NSInvocation mulleInvocationWithTarget:work
                                                        selector:@selector(failingTask)];
    [queue addInvocation:inv2];
    
    sleep(2);
    
    if (queue.state == MulleInvocationQueueError) {
        NSLog(@"Queue cancelled due to error");
    }
    
    [queue terminate];
    [work release];
    
    return 0;
}
```

### Example 5: Final Invocation Cleanup

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface Resource : NSObject
- (void)process:(NSString *)data;
- (void)close;
@end

@implementation Resource
- (void)process:(NSString *)data {
    NSLog(@"Processing: %@", data);
}

- (void)close {
    NSLog(@"Resource cleaned up");
}
@end

int main() {
    Resource *resource = [[Resource alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue invocationQueue];
    [queue start];
    
    // Queue work
    for (int i = 0; i < 2; i++) {
        NSString *data = [NSString stringWithFormat:@"Data%d", i];
        NSInvocation *inv = [NSInvocation mulleInvocationWithTarget:resource
                                                           selector:@selector(process:)
                                                            objects:data];
        [queue addInvocation:inv];
    }
    
    // Queue final cleanup
    NSInvocation *cleanup = [NSInvocation mulleInvocationWithTarget:resource
                                                           selector:@selector(close)];
    [queue addFinalInvocation:cleanup];
    
    sleep(2);
    
    [queue terminate];
    [resource release];
    
    return 0;
}
```

### Example 6: Polling for Completion

```objc
#import <MulleInvocationQueue/MulleInvocationQueue.h>

@interface Task : NSObject
- (void)work;
@end

@implementation Task
- (void)work {
    NSLog(@"Working...");
    sleep(1);
}
@end

int main() {
    Task *task = [[Task alloc] init];
    
    MulleInvocationQueue *queue = [MulleInvocationQueue invocationQueue];
    [queue start];
    
    NSInvocation *inv = [NSInvocation mulleInvocationWithTarget:task
                                                       selector:@selector(work)];
    [queue addInvocation:inv];
    
    // Poll for completion
    while (!MulleInvocationQueueStateIsFinished(queue.state)) {
        if ([queue poll]) {
            NSLog(@"Progress...");
        }
        sleep(1);
    }
    
    NSLog(@"Queue finished in state: %s", 
          MulleInvocationQueueStateUTF8String(queue.state));
    
    [queue terminate];
    [task release];
    
    return 0;
}
```

## 7. Dependencies

- MulleThread (background thread management)
- MulleObjCStandardFoundation (NSInvocation, NSObject)
- mulle-objc (Objective-C runtime)
