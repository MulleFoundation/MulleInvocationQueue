## 0.2.0









feature: export Objective-C dependency loader and improve logging/return handling

* add public MulleObjCDeps+MulleInvocationQueue header+implementation to expose the library's ObjC dependency list to consumers
* include generated objc-deps.inc and wire it into the reflection loader so dependent libraries can declare their load dependencies
* use `mulle_fprintf` for queue tracing and `_mulle_alloca_do_return` to ensure safe return-value handling in NSInvocation utilities
