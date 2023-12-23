# MulleInvocationQueue

#### 🚶🚶🚶 MulleInvocationQueue runs code in a separate thread

A MulleInvocationQueue is fed with NSInvocations, which it then executes in
serial in a separate thread.


| Release Version                                       | Release Notes
|-------------------------------------------------------|--------------
| ![Mulle kybernetiK tag](https://img.shields.io/github/tag/MulleFoundation/MulleInvocationQueue.svg?branch=release) [![Build Status](https://github.com/MulleFoundation/MulleInvocationQueue/workflows/CI/badge.svg?branch=release)](//github.com/MulleFoundation/MulleInvocationQueue/actions) | [RELEASENOTES](RELEASENOTES.md) |


## MulleThread

The MulleThread is the combination of a **NSConditionLock** and **NSThread**.
The thread idles waiting for work. If there is something to do, you `-nudge`
the thread and it runs it's "target" / "selector". Then the thread returns
to idle, waiting for the next `-nudge`.

MulleThread also manages a `NSAutoreleasePool` for your code.


Create a thread and start it:

``` objc
thread = [MulleThread mulleThreadWithTarget:foo
                                   selector:@selector( runServer:)
                                     object:nil];
[thread start];
```

The initial `-start` will not call "target" / "selector" yet. The thread waits
for a `-nudge`. You can `-preempt` the thread at any time. For a more graceful
shutdown use `-cancelWhenIdle`. The thread code can `-cancel` itself at any
time. Use of `+exit` to finish a "MulleThread" is bad style.


``` objc
[thread nudge];
[thread preempt];
[thread cancelWhenIdle];
```

To wait for a thread to complete use `-mulleJoin`. But you need to `-preempt`
or `-cancelWhenIdle` before.





## Requirements

|   Requirement         | Release Version  | Description
|-----------------------|------------------|---------------
| [MulleFoundationBase](https://github.com/MulleFoundation/MulleFoundationBase) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag//.svg) [![Build Status](https://github.com///workflows/CI/badge.svg?branch=release)](https://github.com///actions/workflows/mulle-sde-ci.yml) | 🛸 MulleFoundationBase does something
| [mulle-objc-list](https://github.com/mulle-objc/mulle-objc-list) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag//.svg) [![Build Status](https://github.com///workflows/CI/badge.svg?branch=release)](https://github.com///actions/workflows/mulle-sde-ci.yml) | 📒 Lists mulle-objc runtime information contained in executables.

### You are here

![Overview](overview.dot.svg)

## Add

Use [mulle-sde](//github.com/mulle-sde) to add MulleInvocationQueue to your project:

``` sh
mulle-sde add github:MulleFoundation/MulleInvocationQueue
```

## Install

### Install with mulle-sde

Use [mulle-sde](//github.com/mulle-sde) to build and install MulleInvocationQueue and all dependencies:

``` sh
mulle-sde install --prefix /usr/local \
   https://github.com/MulleFoundation/MulleInvocationQueue/archive/latest.tar.gz
```

### Manual Installation

Install the requirements:

| Requirements                                 | Description
|----------------------------------------------|-----------------------
| [MulleFoundationBase](https://github.com/MulleFoundation/MulleFoundationBase)             | 🛸 MulleFoundationBase does something
| [mulle-objc-list](https://github.com/mulle-objc/mulle-objc-list)             | 📒 Lists mulle-objc runtime information contained in executables.

Download the latest [tar](https://github.com/MulleFoundation/MulleInvocationQueue/archive/refs/tags/latest.tar.gz) or [zip](https://github.com/MulleFoundation/MulleInvocationQueue/archive/refs/tags/latest.zip) archive and unpack it.

Install **MulleInvocationQueue** into `/usr/local` with [cmake](https://cmake.org):

``` sh
cmake -B build \
      -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_PREFIX_PATH=/usr/local \
      -DCMAKE_BUILD_TYPE=Release &&
cmake --build build --config Release &&
cmake --install build --config Release
```

## Author

[Nat!](https://mulle-kybernetik.com/weblog) for Mulle kybernetiK  


