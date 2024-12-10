### 0.1.1

* fix MulleSingleTargetInvocationQueue (tentatively) for TAO

## 0.1.0


feat: improve thread safety and invocation queue handling

* Enhance thread safety with TAO support
  - Add `MULLE_OBJC_THREADSAFE_METHOD` annotations
  - Improve atomic state handling in MulleInvocationQueue
  - Add thread-safe accessors for configuration properties

* Add MulleSingleTargetInvocationQueue for thread-safe target handling
  - Ensure target ownership and access control
  - Manage target lifecycle with mulleGainAccess/mulleRelinquishAccess
  - Support safe target handoff between threads

* Improve invocation queue robustness
  - Add proper cleanup on queue termination
  - Handle final invocations more reliably
  - Add configuration for terminate behavior
  - Fix state transitions and delegate notifications

* Enhance error handling
  - Add mulleReturnStatus support for invocation results
  - Support exception catching configuration
  - Improve cancellation behavior



* mark with `MULLE_OBJC_THREADSAFE_METHOD` what is threadsafe


### 0.0.3

* moved MulleThread into its own project

### 0.0.2

* Various small improvements

### 0.0.1

* Various small improvements
