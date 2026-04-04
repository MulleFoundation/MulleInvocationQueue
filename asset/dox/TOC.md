# MulleInvocationQueue Library Documentation for AI
<!-- Keywords: invocationqueue, thread, nsinvocation, serial, delegate, single-target, objc -->
## 1. Introduction & Purpose

- MulleInvocationQueue executes NSInvocation objects serially in a separate thread.
- Solves: offloading method calls to a worker thread while preserving call order and allowing a "final" invocation to mark completion.
- Key features: configurable behavior flags, execution thread exposure, delegate notifications, final-invocation semantics, single-target specialization.
- Relationship: depends on MulleThread and mulle-objc-list; integrates with Objective-C runtime via NSInvocation categories.

## 2. Key Concepts & Design Philosophy

- Queue model: producers (caller thread) enqueue NSInvocation objects; a worker thread consumes invocations sequentially.
- Final invocation: a special invocation that signals completion; queue can transition to Done state.
- Configuration flags control tracing, exception handling, delegate delivery thread, cancellation semantics.
- Single-target specialization: MulleSingleTargetInvocationQueue "gains" exclusive access to a single target for the queue lifetime.
- Minimal locking and atomic state are used; executionThread and state are exposed for inspection.

## 3. Core API & Data Structures

This section lists the primary public headers and the important symbols an AI should know.

### 3.1. [MulleInvocationQueue.h]

struct/ObjC class: MulleInvocationQueue (subclass of NSObject)
- Purpose: serial execution of NSInvocation objects in a separate thread.
- Key fields (internal): _queueLock, _queue (pointer queue), _atomic_state, _executionThread, _finalInvocation, _configuration, _startTime.
- Properties:
   - delegate (assign) : id<MulleInvocationQueueDelegate>
   - executionThread (readonly) : MulleThread *
   - failedInvocation (readonly) : NSInvocation *
   - exception (readonly) : id
   - state (readonly) : NSUInteger (MulleInvocationQueueState)
   - trace, doneOnEmptyQueue, catchesExceptions, ignoresCaughtExceptions, cancelsOnFailedReturnStatus, messageDelegateOnExecutionThread, terminateWaitsForCompletion (readonly dynamic BOOLs)

- Lifecycle / creation:
   - + (instancetype) invocationQueue;
   - + (instancetype) invocationQueueWithCapacity:(NSUInteger) capacity configuration:(MulleInvocationQueueConfiguration) configuration;
   - - (instancetype) initWithCapacity:(NSUInteger) capacity configuration:(MulleInvocationQueueConfiguration) configuration;

- Control / Execution:
   - - (void) start;
   - - (void) startWithThreadClass:(Class) threadClass;
   - - (void) preempt;
   - - (int) terminate; // 0 OK, -1 fail
   - - (void) cancelWhenIdle;

- Queue operations:
   - - (void) addInvocation:(NSInvocation *) invocation;
   - - (void) addFinalInvocation:(NSInvocation *) invocation;
   - - (BOOL) poll; // not for execution thread
   - - (int) invokeNextInvocation:(id) sender; // synchronous for testing

- Notifications / delegate:
   - Protocol MulleInvocationQueueDelegate: - (void) invocationQueue:(MulleInvocationQueue *) queue didChangeToState:(NSUInteger) state;
   - States: MulleInvocationQueueInit, Idle, Run, Empty, Done, Error, Exception, Cancel, Terminated, Notified.
   - Helpers: MulleInvocationQueueStateUTF8String, MulleInvocationQueueStateIsFinished, MulleInvocationQueueStateCanBeCancelled

### 3.2. [MulleSingleTargetInvocationQueue.h]

- Subclass of MulleInvocationQueue.
- Purpose: Queue optimized for a single target; queue "gains" exclusive access to the target once first invocation is added and releases after finalInvocation.
- Property: target (readonly, retain)
- Use when targets are not thread-safe and you need exclusive ownership for the queue lifetime.

### 3.3. [NSInvocation+MulleReturnStatus.h]

- Category on NSInvocation
- Method: - (BOOL) mulleReturnStatus;
- Purpose: convenience to inspect a boolean-like return value (used by queue when cancelsOnFailedReturnStatus is enabled).

### 3.4. [NSInvocation+UTF8String.h]

- Category on NSInvocation
- Method: - (char *) invocationUTF8String;
- Purpose: produce a UTF8 string representation of invocation for tracing/logging.

## 4. Performance Characteristics

- Enqueue / dequeue: intended O(1) amortized (pointer queue operations).
- Execution: serial on a single worker thread — throughput limited by invocation execution time.
- Memory: stores NSInvocation objects in pointer queue; retains behavior depends on queue internals (finalInvocation assigned/retained via queue logic).
- Thread-safety: public enqueue operations are thread-safe (MULLE_OBJC_THREADSAFE_METHOD); some setup/termination operations must be performed off the execution thread (MULLE_INVOCATION_SETUP_EXECUTION_THREAD_ONLY).
- Trade-offs: simple serial execution for correctness and ease; not designed for parallel invocation execution.

## 5. AI Usage Recommendations & Patterns

- Best practices:
   - Use provided constructors and lifecycle calls (+invocationQueue / initWithCapacity:configuration:).
   - Always add a final invocation if you need a deterministic completion signal.
   - Use -start or -startWithThreadClass: from the creating thread, not the execution thread.
   - Call -terminate to stop the queue; check return value.
   - Observe delegate notifications to track state transitions; delegate messages may come from either thread — handle accordingly.

- Common pitfalls:
   - Do not call setup methods from the execution thread.
   - Be careful with targets that are not thread-safe; prefer MulleSingleTargetInvocationQueue for them.
   - Do not free pointers returned by invocationUTF8String; treat them per library conventions.

- Idiomatic usage:
   - Configure with flags (MulleInvocationQueueConfiguration) to control exception handling and delegate delivery.
   - For boolean return-status protocols, enable MulleInvocationQueueCancelsOnFailedReturnStatus.

## 6. Integration Examples

### Example 1: Creating and starting a queue

```objc
// Create a queue, add invocations, start it
MulleInvocationQueue  *queue;
NSInvocation          *invocation;

queue = [MulleInvocationQueue alloc];
queue = [queue initWithCapacity:128
                  configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
queue = [queue autorelease];

// create invocation (helper from project runtime)
invocation = [NSInvocation mulleInvocationWithTarget:foo
                                             selector:@selector(printUTF8String:), s];

[queue addInvocation:invocation];
[queue start];

// optionally add a final invocation to mark completion
invocation = [NSInvocation mulleInvocationWithTarget:foo
                                             selector:@selector(close), nil];
[queue addFinalInvocation:invocation];
```

### Example 2: Using a single-target queue

```objc
MulleSingleTargetInvocationQueue  *stq;
NSInvocation                       *inv;

stq = [MulleSingleTargetInvocationQueue invocationQueueWithCapacity:64
                                                         configuration:0];

inv = [NSInvocation mulleInvocationWithTarget:resource
                                     selector:@selector(writeData:), data];
[stq addInvocation:inv];
[stq start];

// stq.target is owned by the queue after first invocation is added
```

### Example 3: Inspecting state and failed invocation

```objc
NSUInteger state;

state = [queue state];
if( MulleInvocationQueueStateIsFinished( state))
{
   // finished; examine exception or failedInvocation
   id ex = [queue exception];
   NSInvocation *failed = [queue failedInvocation];
}
```

## 7. Dependencies

- MulleFoundation/MulleThread
- mulle-objc/mulle-objc-list


--
Notes for an AI reader:
- Main public API is found in src/MulleInvocationQueue.h and src/MulleSingleTargetInvocationQueue.h.
- Useful runtime helpers: NSInvocation categories (mulleReturnStatus, invocationUTF8String) live in src and used by queue internals and tracing.
- Tests (under test/) illustrate practical lifecycle; prefer them for edge-case examples.
