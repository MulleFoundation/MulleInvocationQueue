#import <MulleInvocationQueue/MulleInvocationQueue.h>

//#define LEAK_HUNT


@interface DebugInvocationQueue : MulleInvocationQueue
@end

@implementation DebugInvocationQueue

#ifdef LEAK_HUNT
- (id) retain
{
   mulle_fprintf( stderr, "%s: RC=%ld -+-> %ld\n", __FUNCTION__, [self retainCount], [self retainCount] + 1);
   return( [super retain]);
}

- (void) release
{
   mulle_fprintf( stderr, "%s: RC=%ld ---> %ld \n", __FUNCTION__, [self retainCount], [self retainCount] - 1);
   return( [super release]);
}

- (id) autorelease
{
   mulle_fprintf( stderr, "%s: RC=%ld (--> %ld)\n", __FUNCTION__, [self retainCount], [self retainCount] - 1);
   return( [super autorelease]);
}
#endif



- (void) finalize
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super finalize];
}


- (int) invokeNextInvocation:(id) unused
{
   int   rval;

   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   rval = [super invokeNextInvocation:unused];
   mulle_fprintf( stderr, "%s -> %d\n", __FUNCTION__, rval);
   return( rval);
}


- (int) terminate
{
   int   rval;

   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   rval = [super terminate];
   mulle_fprintf( stderr, "%s -> %d\n", __FUNCTION__, rval);
   return( rval);
}


- (void) preempt
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super preempt];
}


- (void) cancelWhenIdle
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super cancelWhenIdle];
}


- (void) start
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super start];
}

@end




@interface DebugThread : MulleThread
@end


@implementation DebugThread

#ifdef LEAK_HUNT
- (id) retain
{
   mulle_fprintf( stderr, "%s: RC=%ld -+-> %ld\n", __FUNCTION__, [self retainCount], [self retainCount] + 1);
   return( [super retain]);
}

- (void) release
{
   mulle_fprintf( stderr, "%s: RC=%ld ---> %ld \n", __FUNCTION__, [self retainCount], [self retainCount] - 1);
   return( [super release]);
}

- (id) autorelease
{
   mulle_fprintf( stderr, "%s: RC=%ld (--> %ld)\n", __FUNCTION__, [self retainCount], [self retainCount] - 1);
   return( [super autorelease]);
}
#endif



- (void) finalize
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super finalize];
}


- (BOOL) isCancelled
{
   BOOL   flag;

   flag = [super isCancelled];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}

- (BOOL) willCallMain
{
   BOOL   flag;

   flag = [super willCallMain];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}


- (BOOL) willIdle
{
   BOOL   flag;

   flag = [super willIdle];
   mulle_fprintf( stderr, "%s -> %btd\n", __FUNCTION__, flag);
   return( flag);
}

- (void) cancelWhenIdle
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super cancelWhenIdle];
}


- (void) cancel
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super cancel];
}


- (void) preempt
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super preempt];
}


- (void) nudge
{
   mulle_fprintf( stderr, "%s\n", __FUNCTION__);
   [super nudge];
}

@end





int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;

   queue  = [DebugInvocationQueue invocationQueue];

   [queue startWithThreadClass:[DebugThread class]];
   [queue cancelWhenIdle];

   mulle_fprintf( stderr, "exiting %s\n", __FUNCTION__);

   return( 0);
}
