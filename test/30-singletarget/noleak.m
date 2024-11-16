#import <MulleInvocationQueue/MulleInvocationQueue.h>


@interface Filehandle : NSObject

- (void) printUTF8String:(char *) s;

@end


@implementation Filehandle

- (void) printUTF8String:(char *) s
{
   printf( "%s\n", s);
}

- (MulleObjCTAOStrategy) mulleTAOStrategy MULLE_OBJC_THREADSAFE_METHOD
{
   return( MulleObjCTAOReceiverPerformsFinalize);
}


@end


@interface Foo : NSObject

@property( retain) Filehandle  *filehandle;

@end


@implementation Foo

- (MulleObjCTAOStrategy) mulleTAOStrategy MULLE_OBJC_THREADSAFE_METHOD
{
   return( MulleObjCTAOReceiverPerformsFinalize);
}

@end


int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation;
   char                   *s;
   Filehandle             *fout;
   Foo                    *foo;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif
   queue = [MulleSingleTargetInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
   queue = [queue autorelease];


//   fout = [Filehandle object];
//
//   invocation = [NSInvocation mulleInvocationWithTarget:fout
//                                               selector:@selector( printUTF8String:), "VfL"];
//   [queue addInvocation:invocation];
//   invocation = [NSInvocation mulleInvocationWithTarget:fout
//                                               selector:@selector( printUTF8String:), "Bochum"];
//   // final is important to get foo fout
//   [queue addFinalInvocation:invocation];
   [queue cancelWhenIdle];
//   [fout printUTF8String:"1848"];

   return( 0);
}
