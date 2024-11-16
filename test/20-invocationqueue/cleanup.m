#import <MulleInvocationQueue/MulleInvocationQueue.h>

int   main( void)
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation;

   @autoreleasepool
   {
      queue = [MulleInvocationQueue invocationQueue];
      invocation = [NSInvocation object];
      [queue addInvocation:invocation];
   }

   return( 0);
}
