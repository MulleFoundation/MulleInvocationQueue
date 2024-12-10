#import <MulleInvocationQueue/MulleInvocationQueue.h>



static inline char  *curr_thread_name( void)
{
   NSThread  *thread;
   char      *name;

   thread = MulleThreadGetCurrentThread();
   name   = thread ? [thread mulleNameUTF8String] : "#?";
   return( name ? name : "??");
}


#define __THREAD_NAME__    curr_thread_name()
#define TEST_TRACE_FRAME


static void   dump_trace_text( unsigned long nr, char *format, va_list args)
{
   auto char   buf[ 19 + 32 + 4 + 1];
   FILE        *fp;

   mulle_snprintf( buf, sizeof( buf), "NSAutoreleasePools_%06d.txt", nr);
   fp = fopen( buf, "w");
   if( ! fp)
   {
      perror( "fopen:");
      return;
   }

   mulle_vfprintf( fp, format, args);
   mulle_fprintf( fp, "\n");

   fclose( fp);
}



static void   dump_trace_stack( unsigned long nr)
{
   auto char   buf[ 19 + 32 + 4 + 1];
   FILE        *fp;

   mulle_snprintf( buf, sizeof( buf), "NSAutoreleasePools_%06d.trc", nr);
   fp = fopen( buf, "w");
   if( ! fp)
   {
      perror( "fopen:");
      return;
   }

   _mulle_stacktrace( NULL, 3, mulle_stacktrace_csv, fp);

   fclose( fp);
}



static void   test_trace( char *format, ...)
{
   va_list   args;

   va_start( args, format);
   mulle_vfprintf( stderr, format, args);
   va_end( args);

#ifdef TEST_TRACE_FRAME
   {
      unsigned long   nr;

      nr = MulleObjCDumpAutoreleasePoolsFrame();
      va_start( args, format);
      dump_trace_text( nr, format, args);
      va_end( args);

      dump_trace_stack( nr);
   }
#endif
}


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

- (void) release
{
   test_trace( "%s - ->: %s %td -> %td\n", __THREAD_NAME__, __FUNCTION__, [self retainCount], [self retainCount] - 1);
   [super release];
}


- (id) retain
{
   self = [super retain];

   test_trace( "%s - +<: %s %td -> %td\n", __THREAD_NAME__, __FUNCTION__, [self retainCount], [self retainCount] + 1);

   return( self);
}


- (id) autorelease
{
   self = [super autorelease];
   test_trace( "%s - a<: %s %td\n", __THREAD_NAME__, __FUNCTION__, [self retainCount]);
   return( self);
}



- (void) dealloc
{
   test_trace( "%s - d>: %s %td\n", __THREAD_NAME__, __FUNCTION__, [self retainCount]);
   [super dealloc];
}

@end


//
// This test only runs single-threaded
//
int   main( int argc, const char * argv[])
{
   MulleInvocationQueue   *queue;
   NSInvocation           *invocation[ 2];
   Filehandle             *fout;

#ifdef __MULLE_OBJC__
   if( mulle_objc_global_check_universe( __MULLE_OBJC_UNIVERSENAME__) != mulle_objc_universe_is_ok)
      return( 1);
#endif

   fout = [Filehandle object];
   test_trace( "%s - #1: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);

   @autoreleasepool
   {
      queue = [MulleSingleTargetInvocationQueue alloc];
      queue = [queue initWithCapacity:128
                        configuration:MulleInvocationQueueMessageDelegateOnExecutionThread];
      queue = [queue autorelease];

      test_trace( "%s - #2: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);

      invocation[ 0] = [NSInvocation mulleInvocationWithTarget:fout
                                                      selector:@selector( printUTF8String:), "VfL"];

      test_trace( "%s - #3: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);
      invocation[ 1] = [NSInvocation mulleInvocationWithTarget:fout
                                                      selector:@selector( printUTF8String:), "Bochum"];

      test_trace( "%s - #4: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);
      [queue addInvocation:invocation[ 0]];
      //[queue addFinalInvocation:invocation[ 1]];
      test_trace( "%s - #5: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);
      [queue cancelWhenIdle];

      test_trace( "%s - #6: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);
   }

   test_trace( "%s - #1: %s %td\n", __THREAD_NAME__, __FUNCTION__, [fout retainCount]);

   [fout printUTF8String:"1848"];

   return( 0);
}
