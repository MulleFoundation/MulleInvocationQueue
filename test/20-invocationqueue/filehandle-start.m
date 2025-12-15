#import <MulleInvocationQueue/MulleInvocationQueue.h>


@interface Filehandle : NSObject < MulleObjCThreadSafe>

- (void) printUTF8String:(char *) s;

@end


@implementation Filehandle

- (void) printUTF8String:(char *) s
{
   printf( "%s\n", s);
}

@end


int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation1;
   NSInvocation           *invocation2;
   Filehandle             *fout;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
   queue = [queue autorelease];

   assert( [queue mulleTAOStrategy] != MulleObjCTAOCallerRemovesFromAllPools);
   assert( [queue mulleTAOStrategy] != MulleObjCTAOCallerRemovesFromCurrentPool);

   //printf( "stacktrace: %s\n", mulle_stacktrace_get_backend( NULL));

   [queue start];

   fout        = [Filehandle instance];

   invocation1 = [NSInvocation mulleInvocationWithTarget:fout
                                                selector:@selector( printUTF8String:), "VfL"];
   [queue addInvocation:invocation1];

   // this will/can already fail, because 'fout' has already been transferred
   // to the MulleInvocationQueue thread.
   invocation2 = [NSInvocation mulleInvocationWithTarget:fout
                                                 selector:@selector( printUTF8String:), "Bochum"];
   [queue addFinalInvocation:invocation2];


   // queue has already started and potentially all invocations have been
   // worked on, which means that fout would now be invalid as it has been
   // passed to the thread/queue. This is somewhat inconvenient though.
   // if you retain/release, "fout" will still belong to the wrong
   // thread
   [queue cancelWhenIdle];

   [fout printUTF8String:"1848"];

   return( 0);
}
