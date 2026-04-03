#import <MulleInvocationQueue/MulleInvocationQueue.h>



@interface Foo : NSObject < MulleInvocationQueueDelegate>
@end


@implementation Foo

- (void) invocationQueue:(MulleInvocationQueue *) queue
        didChangeToState:(NSUInteger) state
{
   mulle_fprintf( stderr, "%s\n", MulleInvocationQueueStateUTF8String( state));
}


- (void) sleep
{
   mulle_printf( "* sleeping\n");
   mulle_relativetime_sleep( 0.5);
   mulle_printf( "* awake\n");
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

   mulle_printf( "# create\n");
   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueMessageDelegateOnExecutionThread
                                   | MulleInvocationQueueTerminateWaitsForCompletion];
   queue = [queue autorelease];

   foo = [Foo instance];

   [queue setDelegate:foo];

   invocation = [NSInvocation mulleInvocationWithTarget:foo
                                               selector:@selector( sleep)];
   mulle_printf( "# add\n");
   [queue addFinalInvocation:invocation];

   mulle_printf( "# start\n");
   [queue start];

   mulle_printf( "# terminate\n");
   [queue terminate];

   mulle_printf( "# exit\n");

   return( 0);
}
