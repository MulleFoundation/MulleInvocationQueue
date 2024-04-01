#import <MulleInvocationQueue/MulleInvocationQueue.h>



@interface Foo : NSObject < MulleInvocationQueueDelegate>
@end


@implementation Foo

- (void) invocationQueueDidChangeState:(MulleInvocationQueue *) queue
{
   NSUInteger   state;

   state = [queue state];
   fprintf( stderr, "%s\n", MulleInvocationQueueStateUTF8String( state));
}

- (void) sleep
{
   printf( "* sleeping\n");
   mulle_relativetime_sleep( 0.5);
   printf( "* awake\n");
}

@end


int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation;
   Foo                    *foo;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   printf( "create\n");
   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread
                                   | MulleInvocationQueueTerminateWaitsForCompletion];
   queue = [queue autorelease];

   foo = [Foo object];

   [queue setDelegate:foo];

   invocation = [NSInvocation mulleInvocationWithTarget:foo
      selector:@selector( sleep)];

   printf( "add\n");
   [queue addFinalInvocation:invocation];

   printf( "start\n");
   [queue start];

   printf( "terminate\n");
   [queue terminate];

   printf( "exit\n");

   return( 0);
}
