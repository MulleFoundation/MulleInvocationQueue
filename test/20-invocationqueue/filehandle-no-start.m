#import <MulleInvocationQueue/MulleInvocationQueue.h>


@interface Filehandle : NSObject

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
   NSInvocation           *invocation;
   Filehandle             *fout;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif
   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
   queue = [queue autorelease];


   fout = [Filehandle object];

   //
   // this autoreleasepool is incovenient, because accessing the filehandle
   // from foo in `test`, will return fout autoreleased. -mulleRelinquish
   // will not delete from the outer pool and complain, unless we use
   // the MulleSingleTargetInvocationQueue
   //
   invocation = [NSInvocation mulleInvocationWithTarget:fout
                                               selector:@selector( printUTF8String:), "VfL"];
   [queue addInvocation:invocation];
   invocation = [NSInvocation mulleInvocationWithTarget:fout
                                               selector:@selector( printUTF8String:), "Bochum"];
   // final is important to get foo fout
   [queue addFinalInvocation:invocation];

   // queue never starts, check that invocations are properly reclaimed
   [queue cancelWhenIdle];

   // so that doesn't fail (will be the only output)
   [fout printUTF8String:"1848"];

   return( 0);
}
