// SPDX-License-Identifier: GPL-2.0
/*
 * Send a raw CXL CCI command on the Secondary Mailbox.
 *
 * Requires the cxl-raw-enabler v6.17 secondary-mailbox kernel patch and
 * CONFIG_CXL_MEM_RAW_COMMANDS=y (plus debugfs raw_allow_all if the opcode
 * is not on the driver's allow list).
 *
 *   gcc -O2 -o cxl-send-secondary cxl-send-secondary.c
 *   sudo ./cxl-send-secondary /dev/cxl/mem0 0x0001
 *
 * Opcode 0x0001 is Identify; output is the standard identify payload.
 */
#include <errno.h>
#include <fcntl.h>
#include <linux/cxl_mem.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#ifndef CXL_MEM_SEND_FLAG_SECONDARY_MBOX
#define CXL_MEM_SEND_FLAG_SECONDARY_MBOX (1U << 16)
#endif

int main(int argc, char **argv)
{
	const char *dev = "/dev/cxl/mem0";
	unsigned long opcode = 0x0001;
	uint8_t out[4096];
	struct cxl_send_command send;
	int fd, rc;

	if (argc >= 2)
		dev = argv[1];
	if (argc >= 3)
		opcode = strtoul(argv[2], NULL, 0);

	fd = open(dev, O_RDWR);
	if (fd < 0) {
		perror(dev);
		return 1;
	}

	memset(&send, 0, sizeof(send));
	memset(out, 0, sizeof(out));
	send.id = CXL_MEM_COMMAND_ID_RAW;
	send.flags = CXL_MEM_SEND_FLAG_SECONDARY_MBOX;
	send.raw.opcode = opcode;
	send.out.size = sizeof(out);
	send.out.payload = (uint64_t)(uintptr_t)out;

	rc = ioctl(fd, CXL_MEM_SEND_COMMAND, &send);
	if (rc < 0) {
		fprintf(stderr, "ioctl: %s\n", strerror(errno));
		if (errno == ENODEV)
			fprintf(stderr,
				"%s has no mapped Secondary Mailbox\n", dev);
		close(fd);
		return 1;
	}

	printf("retval=%u out.size=%u\n", send.retval, send.out.size);
	for (uint32_t i = 0; i < send.out.size; i++) {
		if ((i % 16) == 0)
			printf("%04x:", i);
		printf(" %02x", out[i]);
		if ((i % 16) == 15 || i + 1 == send.out.size)
			putchar('\n');
	}

	close(fd);
	return send.retval ? 2 : 0;
}
