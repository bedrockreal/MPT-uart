	.file	"printf.s"
	.machine ppc
	.section	".text"
.LC0:
	.section	.text.startup.printf,"ax",@progbits
	.align 2
	.globl printf
	.type	printf, @function

printf:
	# r3-r10: arguments

	# prologue: save r14-r19, r3-r10 to stack
	# note: stack frame size = 0x60
	stwu	1, -0x60(1)
	mflr	0
	stw		0, 0x64(1)

	# store r14-r19
	stw		14, 0x8(1)
	addi	14, 1, 0xc
	stswi	15, 14, 0x14

	# store r3-r10
	addi	19, 14, 0x14
	stswi	3, 19, 0x20

	# now r19 points to start address of argument array

	# load 0xcc006800, base address for EXI registers into r14
	lis		14, 0xcc00
	ori		14, 14, 0x6800

	# EXI_Select(EXI_CHANNEL_0,EXI_DEVICE_1,EXI_SPEED8MHZ)
	# bit 9..7 = 010 -> select device 1
	# bit 6..4 = 011 -> 8MHz
	li		9, 0x130
	stw		9, 0x00(14)

	# write "\xa0\x01\x00\x00" to initialise uart output
	mr		15, 3
	lis		3, 0xa001
	li		4, 4
	bl		__uart_write

	# debug (works)
	# lis		3, 0x4142
	# ori		3, 3, 0x430d
	# li		4, 4
	# bl		__uart_write
	# b		printf_post_loop

	# iterate the format string (pointed by r19 now)
	lwz		17, 0x0(19)	# r17 = buf
	addi	17, 17, -1	# it = buf - 1

	printf_loop:
		lbzu	16, 0x1(17)		# r16 = *(++it)
		cmpwi	16, 0x25	# is current character '%'?
		bne		printf_not_format
		
		printf_parse_format:
		# *it == '%'
		# ctr1 checks if the format specifier is valid
		lbzu	18, 0x1(17)		# r18 = *(++it)

		# ignore flag characters
		# TODO

		lwzu	3, 0x4(19)		# r3 = first unused argument
		addi	15, 3, 0		# save r3 to r15

		# check %s and %c
		cmpwi	cr7, 18, 0x73	# is r18 == 's'?
		cmpwi	cr6, 18, 0x63	# is r18 == 'c'?
		bcl		0xc, 4*cr7+eq, write_string
		bcl		0xc, 4*cr6+eq, write_char
		cror	4*cr0+eq, 4*cr6+eq, 4*cr7+eq

		# check %d, %u and %x
		mr		3, 15
		cmpwi	cr7, 18, 0x64	# is r18 == 'd'?
		cmpwi	cr6, 18, 0x75	# is r18 == 'u'?
		cmpwi	cr5, 18, 0x78	# is r18 == 'x'?
		bcl		0xc, 4*cr7+eq, write_int
		bcl		0xc, 4*cr6+eq, write_uint
		bcl		0xc, 4*cr5+eq, write_hex
		cror	4*cr0+eq, 4*cr0+eq, 4*cr7+eq
		cror	4*cr0+eq, 4*cr0+eq, 4*cr6+eq
		cror	4*cr0+eq, 4*cr0+eq, 4*cr5+eq

		beq		printf_loop

		## fallback: ignore this format specifier
		addi	19, 19, -0x4
		addi	17, 17, -1
		

		printf_not_format:
			addic.	3, 16, 0	# r3 = *it, check if r3 == '\0'
			# note: this is simplified from that of write_string
			bcl		4, eq, write_char	# if r3 != '\0', call write_char
			cmpwi	16, 0
			bne		printf_loop	# if *it != '\0', repeat

	printf_post_loop:
	# EXI_Deselect(EXI_CHANNEL_0)
	# set EXI0CSR to 0
	li		3, 0
	stw		3, 0x00(14)
	
	# epilogue: restore non-volatile registers and stack
	## restore r14-r19
	addi	19, 19, -0x18
	lswi	14, 19, 0x14
	lwz		19, 0x14(1)

	## restore stack and return
	lwz		0, 0x64(1)
	mtlr	0
	addi	1, 1, 0x60
	blr

write_string:
	# r3: const char* buf

	# prologue: save r15..r16 to stack
	stwu	1, -0x0020(1)
	mflr	0
	stw		0, 0x0024(1)
	stw		15, 0x8(1)
	stw		16, 0xc(1)

	# iterate the buffer and write it
	addi	15, 3, -1	# it = buf - 1
	write_string_loop:
		lbzu	16, 0x1(15)	# r16 = *(++it)
		addic.	3, 16, 0	# check if (r3 = r16) == '\0'
		bcl		4, eq, write_char	# if r3 != '\0', call write_char
		cmpwi	16, 0		# check if r16 == '\0'
		bne		write_string_loop	# if r16 != '\0', repeat

	# epilogue: restore non-volatile registers and stack
	lwz		0, 0x24(1)
	mtlr	0
	lwz		15, 0x8(1)
	lwz		16, 0xc(1)
	addi	1, 1, 0x20
	blr

write_ubase:
	# write unsigned with base
	# r3 = the 32-bit unsigned integer to write
	# r4 = base (must be 10 or 16)

	# prologue
	stwu	1, -0x30(1)
	mflr	0
	stw		0, 0x34(1)

	# 0x08(1) ro 0x2f(1) inclusive is used as string buffer
	# r9 = pointer to string buffer
	li		5, 0
	la		9, 0x2f(1)
	stb		5, 0x0(9)

	write_ubase_loop:
		# extract digits
		divwu	5, 3, 4		# r5 = floor(r3 / r4)
		mullw	6, 5, 4		# r6 = r4 * floor(r3 * r4)
		subf	6, 6, 3		# r6 = r3 - r6

		# now r6 = r3 mod r4
		li		7, 0x30		# r7 = '0'
		cmpwi	6, 10
		blt		write_ubase_loaded_digit_offset
		# __if r6 >= 10, digit = 'a' - 10 + r6
		li		7, 87		# r7 = 97 ('a') - 10

		write_ubase_loaded_digit_offset:
			add		7, 7, 6		# r7 += r6
			stbu	7, -0x1(9)	# *(--ptr) = digit

		addic.	3, 5, 0		# r3 /= r4 with record
		bne		write_ubase_loop	# __if r3 != 0, repeat

	addi	3, 9, 0		# r3 = string buffer
	bl		write_string

	# epilogue
	lwz		0, 0x34(1)
	mtlr	0
	addi	1, 1, 0x30
	blr

write_uint:
	# printf("%u", r3)
	li		4, 10
	b		write_ubase

write_hex:
	# printf("%x", r3)
	li		4, 16
	b		write_ubase

write_int:
	# prologue
	stwu	1, -0x10(1)
	mflr	0
	stw		0, 0x14(1)

	# printf("%d", r3)
	cmpwi	3, 0
	bge		write_int_positive

	# r3 is negative
	# note: r9 is not modified in write_char
	mr		9, 3		# r9 = r3
	li		3, 0x2d		# r3 = '-'
	bl		write_char
	neg		3, 9		# r3 = -r9

	# TODO: check overflow
	
	write_int_positive:
		bl	write_uint

	# epilogue
	lwz		0, 0x14(1)
	mtlr	0
	addi	1, 1, 0x10
	blr

write_char:
	# r3 \in [0, 256): the byte to write
	# prologue
	# stwu	1, -0x10(1)
	# mflr	0
	# stw		0, 0x14(1)

	cmpwi	3, 0x0a		# check if r3 == '\n'
	bne		write_char_fix_cr
	li		3, 0xd		# change '\n' to '\r' for Dolphin

	write_char_fix_cr:
		slwi	3, 3, 24
		li		4, 1
	# note: fall through to __uart_write (saves 1 branch instruction)
	# bl		__uart_write

	# epilogue
	# lwz		0, 0x14(1)
	# mtlr	0
	# addi	1, 1, 0x10
	# blr

__uart_write:
	# r3: the bytes to be written
	# r4: no. of bytes
	# r14: base address for EXI, already set up

	# prologue
	stwu	1, -0x10(1)
	mflr	0
	stw		0, 0x14(1)


	# # write 0b010101 into EXI0CR
	# # bit 3..2 = 01 -> write
	# # bit 5..4 = 01 -> 2 bytes
	# li		3, 0x15
	# stw		3, 0x0c(14)

	# write r3 into EXI0DATA
	stw		3, 0x10(14)

	# write command 0b__0101 into EXI0CR
	# __ = no. of bytes - 1
	# bit 3..2 = 01 -> write
	# bit 1 = 0 -> immediate (not DMA)
	# bit 0 = 1 -> execute

	# r3 = ((r4 - 1) << 4) + 0b0101, then store
	addi	3, 4, -1
	slwi	3, 3, 4
	addi	3, 3, 5
	stw		3, 0x0c(14)

	# wait until transfer complete
	wait_tc:
	lwz		3, 0x0c(14)
	andi.	3, 3, 1
	bne		wait_tc

	# epilogue
	lwz		0, 0x14(1)
	mtlr	0
	addi	1, 1, 0x10
	blr
