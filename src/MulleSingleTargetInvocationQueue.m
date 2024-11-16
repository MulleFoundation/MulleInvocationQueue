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

- (void) addInvocation:(NSInvocation *) invocation
{
   id   target;

   target = [invocation target];
   if( ! target)
      [NSException raise:NSInvalidArgumentException
                  format:@"invocation target is nil MulleSingleTargetInvocationQueue -addInvocation:"];
   if( ! _target)
      _target = target;
   else
      [invocation setTarget:nil];
   [super addInvocation:invocation];
}


- (void) addFinalInvocation:(NSInvocation *) invocation
{
   id   target;

   target = [invocation target];
   if( ! target)
      [NSException raise:NSInvalidArgumentException
                  format:@"invocation target is nil MulleSingleTargetInvocationQueue -addInvocation:"];
   if( ! _target)
      _target = target;
   else
      [invocation setTarget:nil];

   [super addFinalInvocation:invocation];
}


- (NSInvocation *) popInvocation:(BOOL *) isFinal
{
   NSInvocation   *invocation;

   invocation = [super popInvocation:isFinal];
   if( _target)
      [invocation setTarget:_target];
   return( invocation);
}


- (void) didInvokeFinalInvocation:(NSInvocation *) invocation
{
   [super didInvokeFinalInvocation:invocation];
   [_target mulleRelinquishAccess];
}


- (void) cancelWhenIdle
{
   [super cancelWhenIdle];
   [_target mulleGainAccess];
   _target = nil;
}


- (void) preempt
{
   [super preempt];
   
   [_target mulleGainAccess];
   _target = nil;
}
@end
