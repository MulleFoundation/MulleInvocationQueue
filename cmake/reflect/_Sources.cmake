# This file will be regenerated by `mulle-match-to-cmake` via
# `mulle-sde reflect` and any edits will be lost.
#
# This file will be included by cmake/share/sources.cmake
#
if( MULLE_TRACE_INCLUDE)
   MESSAGE( STATUS "# Include \"${CMAKE_CURRENT_LIST_FILE}\"" )
endif()

#
# contents selected with patternfile ??-source--sources
#
set( SOURCES
src/MulleInvocationQueue.m
src/MulleSingleTargetInvocationQueue.m
src/NSInvocation+MulleReturnStatus.m
src/NSInvocation+UTF8String.m
)

#
# contents selected with patternfile ??-source--stage2-sources
#
set( STAGE2_SOURCES
src/generic/MulleObjCLoader+MulleInvocationQueue.m
)
