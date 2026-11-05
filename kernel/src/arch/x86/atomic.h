/*********************************************************************
 *                
 * Copyright (C) 2007, 2009-2010,  Karlsruhe University
 *                
 * File path:     arch/x86/atomic.h
 * Description:   
 *                
 * @LICENSE@
 *                
 * $Id:$
 *                
 ********************************************************************/
#ifndef __ARCH__X86__ATOMIC_H__
#define __ARCH__X86__ATOMIC_H__

#include "arch/x86/x64/types.h"
#ifdef CONFIG_SMP
# define X86_LOCK "lock;"
#else
# define X86_LOCK
#endif


class atomic_t {
public:
    word_t operator ++ (int) 
	{
	    __asm__ __volatile__(X86_LOCK "add $1, %0" : "=m"(val));
	    return val;
	}

    word_t operator-- (int) 
	{
	    __asm__ __volatile__(X86_LOCK "sub $1, %0" : "=m"(val));
	    return val;
	}
    
    word_t operator = (word_t val) 
	{ return this->val = val; }

    word_t operator = (int val) 
	{ return this->val = val; }

    bool operator == (word_t val) 
	{ return (this->val == val); }
    
    bool operator == (int val) 
	{ return (this->val == (word_t) val); }

    bool operator != (word_t val) 
	{ return (this->val != val); }

    bool operator != (int val) 
	{ return (this->val != (word_t) val); }

    operator word_t (void) 
	{ return val; }

    
    bool cmpxchg( word_t old_val, word_t new_val )
	{
	    word_t expected = old_val;
		unsigned char success;

	    __asm__ __volatile__ (
		X86_LOCK "cmpxchg %3, %1	\n\t"
				 "sete %0		\n\t"
		: "=&q" (success), "+m" (val), "+a"(expected)
		: "r" (new_val)
		: "memory", "cc"
		);
	    return (success != 0);
	}

private:
    word_t val;
};


#endif /* !__ARCH__X86__ATOMIC_H__ */
