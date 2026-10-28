/* Automatically generated, don't edit */
/* Generated on: i30s5 */
/* At: Fri, 09 Nov 2007 12:46:26 +0000 */
/* Linux version 2.6.22.9-0.4-default (geeko@buildhost) (gcc version 4.2.1 (SUSE Linux)) #1 SMP 2007/10/05 21:32:04 UTC */

/* Pistachio Kernel Configuration System */

/* Hardware */

/* Basic Architecture */
#define CONFIG_ARCH_X86 1
#undef  CONFIG_ARCH_POWERPC
#undef  CONFIG_ARCH_POWERPC64


/* X86 Processor Architecture */
#define CONFIG_SUBARCH_X32 1
#undef  CONFIG_SUBARCH_X64


/* Processor Type */
#undef  CONFIG_CPU_X86_I486
#undef  CONFIG_CPU_X86_I586
#undef  CONFIG_CPU_X86_I686
#define CONFIG_CPU_X86_P4 1
#undef  CONFIG_CPU_X86_K8
#undef  CONFIG_CPU_X86_C3
#undef  CONFIG_CPU_X86_SIMICS


/* Platform */
#define CONFIG_PLAT_PC99 1

#undef  CONFIG_SMP

/* Miscellaneous */
#undef  CONFIG_IOAPIC



/* Kernel */
#define CONFIG_IPC_FASTPATH 1
#undef  CONFIG_DEBUG
#undef  CONFIG_DEBUG_SYMBOLS
#define CONFIG_EXPERIMENTAL 1

/* Experimental Features */
#define CONFIG_X_PAGER_EXREGS 1

#define CONFIG_PERFMON 1
#define CONFIG_SPIN_WHEELS 1
#undef  CONFIG_NEW_MDB
#undef  CONFIG_X86_SMALL_SPACES
#undef  CONFIG_X86_IO_FLEXPAGES


/* Debugger */
#undef  CONFIG_KDB

/* Consoles */
#undef  CONFIG_KDB_CONS_OF1275
#undef  CONFIG_KDB_CONS_PSIM_COM


/* Kernel Debugger Console */
#undef  CONFIG_KDB_CONS_KBD
#undef  CONFIG_KDB_CONS_COM

#define CONFIG_KDB_COMPORT 0x3f8
#define CONFIG_KDB_COMSPEED 115200
#undef  CONFIG_KDB_DISAS
#undef  CONFIG_KDB_ON_STARTUP
#undef  CONFIG_KDB_BREAKIN
#undef  CONFIG_KDB_BREAKIN_BREAK
#undef  CONFIG_KDB_BREAKIN_ESCAPE
#undef  CONFIG_KDB_NO_ASSERTS

/* Trace Settings */
#undef  CONFIG_VERBOSE_INIT
#undef  CONFIG_TRACEPOINTS
#undef  CONFIG_KMEM_TRACE
#undef  CONFIG_TRACEBUFFER
#undef  CONFIG_TBUF_PERFMON
#undef  CONFIG_X86_KEEP_LAST_BRANCHES



/* Code Generator Options */


/* Derived symbols */
#undef  CONFIG_HAVE_MEMORY_CONTROL
#define CONFIG_X86_PSE 1
#undef  CONFIG_BIGENDIAN
#define CONFIG_X86_SYSENTER 1
#define CONFIG_X86_PGE 1
#define CONFIG_X86_FXSR 1
#define CONFIG_IS_32BIT 1
#define CONFIG_X86_HTT 1
#define CONFIG_X86_PAT 1
#undef  CONFIG_IS_64BIT
#undef  CONFIG_MULTI_ARCHITECTURE
#undef  CONFIG_X86_EM64T
#undef  CONFIG_X86_SMALL_SPACES_GLOBAL
#define CONFIG_X86_TSC 1
/* That's all, folks! */
#define AUTOCONF_INCLUDED
