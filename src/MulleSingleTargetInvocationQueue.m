//
//  MulleSingleTargetInvocationQueue.m
//  MulleInvocationQueue
//
//  Copyright (c) 2024 Nat! - Mulle kybernetiK.
//  All rights reserved.
//
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#import "MulleSingleTargetInvocationQueue.h"

#import "import-private.h"


@interface MulleInvocationQueue( Private)

- (NSInvocation *) popInvocation:(BOOL *) isFinal;
- (void) didInvokeFinalInvocation:(NSInvocation *) invocation;

@end


@implementation MulleSingleTargetInvocationQueue

- (void) _prepareInvocation:(NSInvocation *) invocation
{
   id   target;

   target = [invocation target];
   assert( target || "invocation target is nil for MulleSingleTargetInvocationQueue");

   if( ! _target)
   {
      _target = [target retain];
      [_target mulleRelinquishAccess];
   }

   // the invocation also retains the target with this, so we gotta undo this
   if( [invocation argumentsRetained])
      [target autorelease];
   [invocation setTarget:nil];
}


- (void) addInvocation:(NSInvocation *) invocation
{
   [self _prepareInvocation:invocation];
   [super addInvocation:invocation];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   [self _prepareInvocation:invocation];
   [super addFinalInvocation:invocation];
}


- (NSInvocation *) popInvocation:(BOOL *) isFinal
{
   NSInvocation   *invocation;

   invocation = [super popInvocation:isFinal];
   assert( [invocation argumentsRetained]);
   assert( ! [invocation target]);

   if( ! _executionThreadGainedAccessToTarget)
   {
      [_target mulleGainAccess];
      _executionThreadGainedAccessToTarget = YES;
   }

   [invocation setTarget:[_target retain]];

   return( invocation);
}


- (void) didInvokeFinalInvocation:(NSInvocation *) invocation
{
   [super didInvokeFinalInvocation:invocation];

   // not sure how this can be NO ever
   assert( _executionThreadGainedAccessToTarget);
   [_target mulleRelinquishAccess];
}


- (void) cancelWhenIdle
{
   [super cancelWhenIdle];

   [_target autorelease];
   [_target mulleGainAccess];
   _target = nil;
}


- (void) preempt
{
   [super preempt];
   
   [_target autorelease];
   [_target mulleGainAccess];
   _target = nil;
}

@end
