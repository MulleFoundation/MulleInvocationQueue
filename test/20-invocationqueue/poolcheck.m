#import <MulleInvocationQueue/MulleInvocationQueue.h>



@interface Foo : NSObject

@end


@implementation Foo

+ (instancetype) object
{
   printf( "object\n");
   return( [super object]);
}


- (void) dealloc
{
   printf( "dealloc\n");
   [super dealloc];
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

   queue = [MulleInvocationQueue alloc];
   queue = [queue initWithCapacity:128
                     configuration:MulleInvocationQueueTerminateWaitsForCompletion];
   queue = [queue autorelease];

   invocation = [NSInvocation mulleInvocationWithTarget:[Foo class]
                                               selector:@selector( object)];
   [queue addInvocation:invocation];
   [queue start];
   [queue terminate];

   return( 0);
}
