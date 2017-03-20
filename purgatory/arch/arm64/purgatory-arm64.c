/*
 * ARM64 purgatory.
 */

#include <stdint.h>
#include <purgatory.h>

void enable_dcache(void);
void disable_dcache(void);
/* Symbols set by kexec. */

uint8_t *arm64_sink __attribute__ ((section ("data")));
uint8_t *arm64_sink_lsr __attribute__ ((section ("data")));
uint8_t arm64_sink_lsr_val __attribute__ ((section ("data")));
extern void (*arm64_kernel_entry)(uint64_t, uint64_t, uint64_t, uint64_t);
extern uint64_t arm64_dtb_addr;

static void wait_for_xmit_complete(void)
{
	volatile uint8_t status;
	volatile uint8_t *status_reg = (volatile uint8_t *)arm64_sink_lsr;
	int read_count = 0;

	if (!arm64_sink_lsr)
		return;

	while (read_count++ < 1000) {
		status = *status_reg;
		if ((status & arm64_sink_lsr_val) == arm64_sink_lsr_val)
			break;
	}
}

void putchar(int ch)
{
	if (!arm64_sink)
		return;

	wait_for_xmit_complete();
	*arm64_sink = ch;

	if (ch == '\n') {
		wait_for_xmit_complete();
		*arm64_sink = '\r';
	}
}

void post_verification_setup_arch(void)
{
	disable_dcache();
	printf("purgatory: D-cache Disabled after SHA verification\n");
}

void setup_arch(void)
{
	printf("purgatory: entry=%lx\n", (unsigned long)arm64_kernel_entry);
	printf("purgatory: dtb=%lx\n", arm64_dtb_addr);
	enable_dcache();
	printf("purgatory: D-cache Enabled before SHA verification\n");
}
