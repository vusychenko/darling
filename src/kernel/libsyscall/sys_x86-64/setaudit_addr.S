#define __SYSCALL_32BIT_ARG_BYTES 8
#include "SYS.h"

#ifndef SYS_setaudit_addr
#error "SYS_setaudit_addr not defined. The header files libsyscall is building against do not match syscalls.master."
#endif

#if defined(__x86_64__)
__SYSCALL2(setaudit_addr, setaudit_addr, 2, cerror_nocancel)
#endif

