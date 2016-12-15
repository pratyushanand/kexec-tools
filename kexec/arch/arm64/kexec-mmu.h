/*
* Based on linux v4.11's arch/arm64/include/asm/pgtable-hwdef.h
* Copyright (C) 2012 ARM Ltd.
*/

#if !defined(KEXEC_MMU_H)
#define KEXEC_MMU_H

#define SCTLR_ELx_I		(1 << 12)
#define SCTLR_ELx_C		(1 << 2)
#define SCTLR_ELx_M		(1 << 0)
#define SCTLR_ELx_FLAGS 	(SCTLR_ELx_M | SCTLR_ELx_C | SCTLR_ELx_I)
#define TCR_SHARED_NONE		(0 << 12)
#define TCR_ORGN_WBWA		(1 << 10)
#define TCR_IRGN_WBWA		(1 << 8)
#define TCR_T0SZ_48		16
#define TCR_TG0_4K		(0 << 14)
#define TCR_FLAGS 		(TCR_SHARED_NONE | TCR_ORGN_WBWA |\
				TCR_IRGN_WBWA | TCR_T0SZ_48 | TCR_TG0_4K)
#define TCR_IPS_EL1_SHIFT	32
#define TCR_IPS_EL2_SHIFT	16
#define ID_AA64MMFR0_TGRAN4_SHIFT	28
#define ID_AA64MMFR0_PARANGE_MASK	0xF
#define MT_NORMAL		0
#define MEMORY_ATTRIBUTES	(0xFF << (MT_NORMAL*8))

/*
 * kexec creates identity page table to be used in purgatory so that
 * SHA verification of the image can make use of the dcache.
 *
 * These are the definitions to be used by page table creation routine.
 *
 * Only 4K page table, 4 level, 2M block mapping at 3rd Level,
 * 48bit VA is supported
 */
#define VA_BITS			48
#define PAGE_SHIFT		12
#define PGTABLE_LEVELS		4
#define ARM64_HW_PGTABLE_LEVEL_SHIFT(n) ((PAGE_SHIFT - 3) * (4 - (n)) + 3)
#define PGDIR_SHIFT		ARM64_HW_PGTABLE_LEVEL_SHIFT(4 - PGTABLE_LEVELS)
#define PTRS_PER_PGD		(1 << (VA_BITS - PGDIR_SHIFT))
#define PUD_SHIFT		ARM64_HW_PGTABLE_LEVEL_SHIFT(1)
#define PMD_SHIFT		ARM64_HW_PGTABLE_LEVEL_SHIFT(2)
#define PMD_SIZE		(1UL << PMD_SHIFT)
#define PMD_MASK		(~(PMD_SIZE-1))
#define SWAPPER_TABLE_SHIFT	PUD_SHIFT
#define PTRS_PER_PTE		(1 << (PAGE_SHIFT - 3))
#define PTRS_PER_PMD		PTRS_PER_PTE
#define pmd_index(addr)		(((addr) >> PMD_SHIFT) & (PTRS_PER_PMD - 1))
#define PMD_TYPE_TABLE		(3UL << 0)
#define PMD_TYPE_SECT		(1UL << 0)
#define PMD_SECT_AF		(1UL << 10)
#define PMD_ATTRINDX(t)		((unsigned long)(t) << 2)
#define PMD_FLAGS_NORMAL	(PMD_TYPE_SECT | PMD_SECT_AF)
#define MMU_FLAGS_NORMAL	(PMD_ATTRINDX(MT_NORMAL) | PMD_FLAGS_NORMAL)
#define SECTION_SHIFT		PMD_SHIFT
#define SECTION_SIZE		(1UL << SECTION_SHIFT)
#define PAGE_SIZE		(1 << PAGE_SHIFT)
/*
 * Since we are using 4 level of page tables, but section mapping at 3ed
 * level, therefore minimum number of table will be 3. Each entry in level
 * 3 page table can map 2MB memory area. Thus a level 3 page table indexed
 * by bit 29:21 can map a total of 1G memory area. Therefore, if any
 * segment crosses 1G boundary, then we will need one more level 3 table.
 * Similarly, level 2 page table indexed by bit 38:30 can map a total of
 * 512G memory area. If segment addresses are more than 512G apart then we
 * will need two more table for each such block. Lets consider 2G as the
 * maximum size of crashkernel+initramfs. This 2G memory
 * location might not be allocated at 1G aligned boundary, so in that case
 * we need to have 5 table size reserved to map any location of the crash
 * kernel region.
 *
 * If we will ever wish to support uart debugging in purgatory then that
 * might cross the boundary and therefore additional 2 more table space. In
 * that case, we will need a total of 7 table space.
 *
 * As of now keep it fixed at 5. Increase it if any platform either
 * supports uart or more than 2G of crash kernel size.
 */
#define MAX_PGTBLE_SZ	(5 * PAGE_SIZE)

#endif
