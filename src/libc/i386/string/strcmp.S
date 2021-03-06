// Modified by Lubos Dolezel for Darling
/*
 * Copyright (c) 2005 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#ifdef DARLING
#	define _strcmp strcmp
#endif

// ***************
// * S T R C M P *
// ***************
//
// int	strcmp(const char *s1, const char *s2);
//
// We optimize the compare by doing it in parallel, using SSE.  This introduces
// a complication: if we blindly did vector loads from both sides until
// finding a difference (or 0), we might get a spurious page fault by
// reading bytes past the difference.  To avoid this, we never do a load
// that crosses a page boundary.

        .text
        .globl _strcmp

        .align 	(1<<4)
_strcmp:				// int strcmp(const char *s1,const char *s2);
	pushl	%esi
	pushl	%edi
	movl	12(%esp),%esi		// get LHS ptr
	movl	16(%esp),%edi		// get RHS ptr
	

// In order to avoid spurious page faults, we loop over:
//
//	min( bytes_in_LHS_page, bytes_in_RHS_page) >> 4
//
// 16-byte chunks.  When we near a page end, we have to revert to a byte-by-byte
// comparison until reaching the next page, then resume the vector comparison.
//	%esi = LHS ptr
//	%edi = RHS ptr

LNextChunk:
	movl	%esi,%eax		// copy ptrs
	movl	%edi,%edx
	andl	$4095,%eax		// mask down to page offsets
	andl	$4095,%edx
	cmpl	%eax,%edx		// which is bigger?
	cmova	%edx,%eax		// %eax = max(LHS offset, RHS offset);
	movl	$4096,%edx
	subl	%eax,%edx		// get #bytes to next page crossing
	movl	%edx,%eax
	shrl	$4,%edx			// get #chunks till end of operand or page
	jnz	LLoopOverChunks		// enter vector loop
	movl	%eax,%edx		// no chunks...
	jmp	LLoopOverBytes		// ...so loop over bytes until page end


// Loop over bytes.
//	%esi = LHS ptr
//	%edi = RHS ptr
//	%edx = byte count

	.align	(1<<4),0x90			// align inner loops to optimize I-fetch
LLoopOverBytes:
	movzb	(%esi),%eax		// get LHS byte
	movzb	(%edi),%ecx		// get RHS byte
	inc	%esi
	inc	%edi
	testl	%eax,%eax		// 0?
	jz	LExit0			// yes, we're done
	subl	%ecx,%eax		// compare them
	jnz	LExit			// done if not equal
	dec	%edx			// more to go?
	jnz	LLoopOverBytes
	
	jmp	LNextChunk		// we've come to end of page


// Loop over 16-byte chunks.
//	%esi = LHS ptr
//	%edi = RHS ptr
//	%edx = chunk count

	.align	(1<<4),0x90			// align inner loops to optimize I-fetch
LLoopOverChunks:
	movdqu	(%esi),%xmm1		// get LHS
	movdqu	(%edi),%xmm2		// get RHS
	pxor	%xmm0,%xmm0		// get some 0s in the shadow of the loads
	addl	$16,%esi
	pcmpeqb	%xmm1,%xmm2		// compare LHS to RHS
	pcmpeqb	%xmm1,%xmm0		// compare LHS to 0s
	addl	$16,%edi
	pmovmskb %xmm2,%eax		// get result mask for comparison of LHS and RHS
	pmovmskb %xmm0,%ecx		// get result mask for 0 check
	xorl	$0xFFFF,%eax		// complement compare mask so 1 means "not equal"
	orl	%ecx,%eax		// combine the masks and check for 1-bits
	jnz	LFoundDiffOr0		// we found differing bytes or a 0-byte
	dec	%edx			// more to go?
	jnz	LLoopOverChunks
	
	jmp	LNextChunk		// compare up to next page boundary
	

// Found a zero and/or a difference in vector compare.
//	%esi = LHS ptr, already advanced by 16
//	%edi = RHS ptr, already advanced by 16
//	%eax = bit n set if bytes n differed or were 0

LFoundDiffOr0:
	bsf	%eax,%edx		// which byte differed or was 0?
	subl	$16,%esi		// point to start of vectors while we wait for bit scan
	subl	$16,%edi
	movzb	(%esi,%edx),%eax	// get LHS byte
	movzb	(%edi,%edx),%ecx	// get RHS byte
	subl	%ecx,%eax		// compute difference (ie, return value)
	popl	%edi
	popl	%esi
	ret


// Found a zero and/or difference in byte loop.
//	%eax = LHS byte
//	%ecx = RHS byte

LExit0:
	subl	%ecx,%eax		// compute difference (ie, return value)
LExit:					// here with difference already in %eax
	popl	%edi
	popl	%esi
	ret
