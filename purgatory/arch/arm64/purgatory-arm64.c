/*
 * ARM64 purgatory.
 */

#include <stdint.h>
#include <purgatory.h>

void enable_dcache(void);
void disable_dcache(void);

void putchar(int ch)
{
	/* Nothing for now */
}

void post_verification_setup_arch(void)
{
	disable_dcache();
}

void setup_arch(void)
{
	enable_dcache();
}
