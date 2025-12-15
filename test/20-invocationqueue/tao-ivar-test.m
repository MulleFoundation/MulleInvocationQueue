#import <MulleObjC/MulleObjC.h>

@interface Bar : NSObject
@end

@implementation Bar

- (void) dealloc
{
   mulle_printf( "Bar dealloc\n");
   [super dealloc];
}

@end


@interface Baz : NSObject
@end

@implementation Baz

- (void) dealloc
{
   mulle_printf( "Baz dealloc\n");
   [super dealloc];
}

@end


@interface Foo : NSObject

@property( retain, readonly) Bar *bar;
@property( retain)           Baz *baz;

@end


@implementation Foo

- (instancetype) init
{
   [super init];
   _bar = [[Bar alloc] init];  // RC = 1, owned by Foo
   _baz = [[Baz alloc] init];  // RC = 1, owned by Foo
   mulle_printf( "Foo created with Bar (RC=%ld), Baz (RC=%ld)\n",
                 (long)[_bar retainCount], (long)[_baz retainCount]);
   return( self);
}

- (void) finalize
{
   mulle_printf( "Foo finalize, releasing Baz (RC=%ld) implicitly\n",
                 (long)[_baz retainCount]);
   [super finalize];
}

- (void) dealloc
{
   mulle_printf( "Foo dealloc, releasing Bar (RC=%ld) explicitly\n",
                 (long)[_bar retainCount]);
   [_bar release];  // Foo explicitly releases Bar, like NSInvocation does
   [super dealloc];
}

@end


int main()
{
   NSAutoreleasePool   *pool;
   Foo                 *foo;
   
   pool = [NSAutoreleasePool new];
   
   mulle_printf( "=== Creating Foo ===\n");
   foo = [[Foo alloc] init];
   mulle_printf( "Foo RC after alloc/init: %ld\n", (long)[foo retainCount]);
   
   mulle_printf( "\n=== Relinquishing Foo (simulate transfer to thread) ===\n");
   [foo retain];  // TAO does this
   mulle_printf( "Foo RC after retain: %ld\n", (long)[foo retainCount]);
   [foo mulleRelinquishAccess];
   mulle_printf( "Foo RC after relinquish: %ld\n", (long)[foo retainCount]);
   
   mulle_printf( "\n=== Gaining Foo back (simulate return from thread) ===\n");
   [foo mulleGainAccess];
   mulle_printf( "Foo RC after gain: %ld\n", (long)[foo retainCount]);
   [foo autorelease]; // TAO does this
   mulle_printf( "Foo RC after autorelease: %ld\n", (long)[foo retainCount]);
   
   mulle_printf( "\n=== Releasing Foo ===\n");
   [foo release];
   mulle_printf( "Foo RC after explicit release: %ld\n", (long)[foo retainCount]);
   
   mulle_printf( "\n=== Draining pool (should release Foo once more) ===\n");
   [pool release];
   
   mulle_printf( "\n=== Done ===\n");
   return( 0);
}
