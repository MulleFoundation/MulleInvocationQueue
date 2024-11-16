//
//  NSInvocation+BoolValue.m
//  MulleInvocationQueue
//
//  Copyright (c) 2022 Nat! - Mulle kybernetiK.
//  Copyright (c) 2022 Codeon GmbH.
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
#import "NSInvocation+MulleReturnStatus.h"

#import "import-private.h"


@interface NSObject ( BoolValue)

- (BOOL) boolValue;

@end


@implementation NSInvocation ( MulleReturnStatus)

- (BOOL) mulleReturnStatus
{
   NSUInteger          length;
   char                *returnType;
   NSMethodSignature   *methodSignature;
   id                  obj;
   char                *p, *sentinel;

   methodSignature = [self methodSignature];
   returnType      = [methodSignature methodReturnType];
   length          = 0;

   switch( *returnType)
   {
   default           : length = [methodSignature methodReturnLength]; break;
   case _C_VOID      : return( NO);
   case _C_SEL       : length = sizeof( mulle_objc_methodid_t); break;
   case _C_CHR       : length = sizeof( char); break;
   case _C_BOOL      : length = sizeof( int); break;
   case _C_UCHR      : length = sizeof( unsigned char); break;
   case _C_SHT       : length = sizeof( short); break;
   case _C_USHT      : length = sizeof( unsigned short); break;
   case _C_INT       : length = sizeof( int); break;
   case _C_UINT      : length = sizeof( unsigned int); break;
   case _C_LNG       : length = sizeof( long); break;
   case _C_ULNG      : length = sizeof( unsigned long); break;
   case _C_LNG_LNG   : length = sizeof( long long); break;
   case _C_ULNG_LNG  : length = sizeof( unsigned long long); break;
   case _C_FLT       : length = sizeof( float); break;
   case _C_DBL       : length = sizeof( double); break;
   case _C_LNG_DBL   : length = sizeof( long double); break;
   case _C_CHARPTR   : length = sizeof( char *); break;
   case _C_UNDEF     : length = sizeof( void *); break;
   case _C_ATOM      : length = sizeof( char *); break;
   case _C_ASSIGN_ID :
   case _C_COPY_ID   :
   case _C_CLASS     :
   case _C_RETAIN_ID : length = sizeof( id);
                       [self getReturnValue:&obj];
                       if( ! obj)
                          return( YES);
                       if( [obj respondsToSelector:@selector( boolValue)])
                          return( [obj boolValue]);
                       return( NO);
   }

   // for ints and doubles everything not zero is a YES
   mulle_alloca_do( buf, char, length)
   {
      [self getReturnValue:buf];
      for( p = buf, sentinel = &buf[ length]; p < sentinel; p++)
         if( *p)
            return( YES);
   }
   return( NO);
}

@end
