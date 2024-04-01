#import <MulleInvocationQueue/MulleInvocationQueue.h>



@interface Foo : NSObject < MulleObjCThreadSafe, MulleInvocationQueueDelegate>
@end


@implementation Foo

- (void) invocationQueueDidChangeState:(MulleInvocationQueue *) queue
{
   NSUInteger   state;

   state = [queue state];
   fprintf( stderr, "%s\n", MulleInvocationQueueStateUTF8String( state));
}

- (void) printUTF8String:(char *) s
{
   printf( "%s\n", s);
}

@end


int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation;
   char                   *s;
   Foo                    *foo;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif
   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
   queue = [queue autorelease];

   foo = [Foo object];
   [queue setDelegate:foo];

   s = mulle_strdup( "VfL Bochum 1848");

   @autoreleasepool
   {
      invocation = [NSInvocation mulleInvocationWithTarget:foo
         selector:@selector( printUTF8String:), s];

      [queue addInvocation:invocation];
   }

   invocation = [NSInvocation mulleInvocationWithTarget:foo
      selector:@selector( printUTF8String:), s];

   [queue addFinalInvocation:invocation];

   [queue invokeNextInvocation:nil];
   [queue invokeNextInvocation:nil];

   mulle_free( s);

   return( 0);
}
