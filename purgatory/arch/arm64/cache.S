/*
 * Some of the routines have been copied from Linux Kernel, therefore
 * copying the license as well.
 *
 * Copyright (C) 2001 Deep Blue Solutions Ltd.
 * Copyright (C) 2012 ARM Ltd.
 * Copyright (C) 2016 Pratyush Anand <panand@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "../../../kexec/arch/arm64/kexec-mmu.h"
/*
 * 	dcache_line_size - get the minimum D-cache line size from the CTR register.
 */
	.macro	dcache_line_size, reg, tmp
	mrs	\tmp, ctr_el0			// read CTR
	ubfm	\tmp, \tmp, #16, #19		// cache line size encoding
	mov	\reg, #4			// bytes per word
	lsl	\reg, \reg, \tmp		// actual cache line size
	.endm

/*
 *	flush_dcache_range(start, end)
 *	- x0 - start	- start address of region
 *	- x1 - end	- end address of region
 *
 */
flush_dcache_range:
	dcache_line_size x2, x3
	sub	x3, x2, #1
	bic	x0, x0, x3
1:	dc	civac, x0			// clean & invalidate D line / unified line
	add	x0, x0, x2
	cmp	x0, x1
	b.lo	1b
	dsb	sy
	ret

/*
 *	invalidate_tlbs_el1()
 */
invalidate_tlbs_el1:
	dsb	nshst
	tlbi	vmalle1
	dsb	nsh
	isb
	ret

/*
 *	invalidate_tlbs_el2()
 */
invalidate_tlbs_el2:
	dsb	nshst
	tlbi	alle2
	dsb	nsh
	isb
	ret
/*
 *	is_4k_page_not_supported - return nonzero if 4k page is not supported
 */
is_4k_page_not_supported:
	mrs	x0, ID_AA64MMFR0_EL1
	and	x0, x0, #(0xF << ID_AA64MMFR0_TGRAN4_SHIFT)
	ret

/*
 *	get_ips_bits - return supported IPS bits
 */
get_ips_bits:
	mrs	x0, ID_AA64MMFR0_EL1
	and	x0, x0, #ID_AA64MMFR0_PARANGE_MASK
	ret

/*
 * 	get_current_el - Get information about current exception level
 */
get_current_el:
	mrs 	x0, CurrentEL
	lsr	x0, x0, #2
	ret

/*
 * 	invalidate_icache - Invalidate I-cache
 */
invalidate_icache:
	ic	iallu
	dsb	nsh
	isb
	ret

/*
 * 	set_mair_tcr_ttbr_sctlr_el1(page_table, tcr_flags) - sets MAIR, TCR , TTBR and SCTLR registers
 * 	x0 - page_table - Page Table Base
 * 	x1 - tcr_flags - TCR Flags to be set
 */
set_mair_tcr_ttbr_sctlr_el1:
	ldr	x2, =MEMORY_ATTRIBUTES
	msr	mair_el1, x2
	msr	tcr_el1, x1
	msr	ttbr0_el1, x0
	isb
	mrs	x0, sctlr_el1
	ldr	x3, =SCTLR_ELx_FLAGS
	orr	x0, x0, x3
	msr	sctlr_el1, x0
	isb
	ret

/*
 * 	set_mair_tcr_ttbr_sctlr_el2(page_table, tcr_flags) - sets MAIR, TCR , TTBR and SCTLR registers
 * 	x0 - page_table - Page Table Base
 * 	x1 - tcr_flags - TCR Flags to be set
 */
set_mair_tcr_ttbr_sctlr_el2:
	ldr	x2, =MEMORY_ATTRIBUTES
	msr	mair_el2, x2
	msr	tcr_el2, x1
	msr	ttbr0_el2, x0
	isb
	mrs	x0, sctlr_el2
	ldr	x3, =SCTLR_ELx_FLAGS
	orr	x0, x0, x3
	msr	sctlr_el2, x0
	isb
	ret

/*
 * reset_sctlr_el1 - disables cache and mmu
 */
reset_sctlr_el1:
	mrs	x0, sctlr_el1
	bic	x0, x0, #SCTLR_ELx_C
	bic	x0, x0, #SCTLR_ELx_M
	msr	sctlr_el1, x0
	isb
	ret

/*
 * reset_sctlr_el2 - disables cache and mmu
 */
reset_sctlr_el2:
	mrs	x0, sctlr_el2
	bic	x0, x0, #SCTLR_ELx_C
	bic	x0, x0, #SCTLR_ELx_M
	msr	sctlr_el2, x0
	isb
	ret

.globl enable_dcache
/*
 * x6 - pgtble_base
 * x7 - tcr_flags
 * x8 - current_el
 */
enable_dcache:
	stp	x29, x30, [sp,#-16]!
	stp	x6, x7, [sp,#-16]!
	stp	x8, x9, [sp,#-16]!
	bl	is_4k_page_not_supported
	cmp	x0, #0
	b.ne	1f
	ldr	x6, pgtble_base
	ldr	x7, =TCR_FLAGS
	bl	get_current_el
	mov	x8, x0
	cmp	x8, #2
	b.ne	2f
	bl	invalidate_tlbs_el2
	bl	get_ips_bits
	lsl	x1, x0, #TCR_IPS_EL2_SHIFT
	orr	x1, x1, x7
	mov	x0, x6
	bl	set_mair_tcr_ttbr_sctlr_el2
	b	1f
2:
	cmp	x8, #1
	b.ne	1f
	bl	invalidate_tlbs_el1
	bl	get_ips_bits
	lsl	x1, x0, #TCR_IPS_EL1_SHIFT
	orr	x1, x1, x7
	mov	x0, x6
	bl	set_mair_tcr_ttbr_sctlr_el1
1:
	ldp	x8, x9, [sp],#16
	ldp	x6, x7, [sp],#16
	ldp	x29, x30, [sp],#16
	ret

.extern sha256_regions
.globl disable_dcache
/*
 * x6 - pgtble_base
 * x7 - current_el
 */
disable_dcache:
	stp	x29, x30, [sp,#-16]!
	stp	x6, x7, [sp,#-16]!
	bl	is_4k_page_not_supported
	cmp	x0, #0
	b.ne	1f
	ldr	x6, pgtble_base
	bl	get_current_el
	mov	x7, x0
	cmp	x7, #2
	b.ne	2f
	bl	reset_sctlr_el2
	b	3f
2:
	cmp	x7, #1
	b.ne	1f
	bl	reset_sctlr_el1
3:
	/*
	 * we can only branch to function which does not use stack, until
	 * all memories are flushed.
	 */
	bl	invalidate_icache
	/* flush d cache for purgatory region */
	ldr	x0, purgatory_base
	ldr	x1, purgatory_len
	add	x1, x1, x0
	bl	flush_dcache_range
	/* flush d cache for rest of the regions */
	ldr	x6, =sha256_regions
4:
	ldp	x0, x1, [x6],#16
	cmp	x1, #0
	b.eq	1f
	add	x1, x1, x0
	bl	flush_dcache_range
	b	4b
1:
	ldp	x6, x7, [sp],#16
	ldp	x29, x30, [sp],#16
	ret

.align 3

.globl pgtble_base
pgtble_base:
	.quad	0
	.size	pgtble_base, .-pgtble_base

.globl purgatory_base
purgatory_base:
	.quad	0
	.size	purgatory_base, .-purgatory_base

.globl purgatory_len
purgatory_len:
	.quad	0
	.size	purgatory_len, .-purgatory_len
