/*
 *   This file will be regenerated by `mulle-project-versioncheck`.
 *   Any edits will be lost.
 */
#ifndef mulle_invocation_queue_versioncheck_h__
#define mulle_invocation_queue_versioncheck_h__

#if defined( MULLE_THREAD_VERSION)
# ifndef MULLE_THREAD_VERSION_MIN
#  define MULLE_THREAD_VERSION_MIN  ((0UL << 20) | (2 << 8) | 0)
# endif
# ifndef MULLE_THREAD_VERSION_MAX
#  define MULLE_THREAD_VERSION_MAX  ((0UL << 20) | (3 << 8) | 0)
# endif
# if MULLE_THREAD_VERSION < MULLE_THREAD_VERSION_MIN || MULLE_THREAD_VERSION >= MULLE_THREAD_VERSION_MAX
#  pragma message("MULLE_THREAD_VERSION     is " MULLE_C_STRINGIFY_MACRO( MULLE_THREAD_VERSION))
#  pragma message("MULLE_THREAD_VERSION_MIN is " MULLE_C_STRINGIFY_MACRO( MULLE_THREAD_VERSION_MIN))
#  pragma message("MULLE_THREAD_VERSION_MAX is " MULLE_C_STRINGIFY_MACRO( MULLE_THREAD_VERSION_MAX))
#  if MULLE_THREAD_VERSION < MULLE_THREAD_VERSION_MIN
#   error "MulleThread is too old"
#  else
#   error "MulleThread is too new"
#  endif
# endif
#endif

#endif
