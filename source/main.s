	.file	"main.s"
	.machine ppc
	.section	".text"
.LC0:
	.section	.text.startup.main,"ax",@progbits
	.align 2
	.globl main
	.type	main, @function
.STR1:
	.string "Hello, %s%c %d %u %x\n"
	.align 2
.STR2:
	.string "World"
	.align 2

main:
	lis		3, .STR1@ha
	la		3, .STR1@l(3)
	lis		4, .STR2@ha
	la		4, .STR2@l(4)
	li		5, 0x21	# '!'
	li		6, -0x4	# -4
	li		7, 100
	li		8, 0xff
	bl		printf

	lis		3, .STR1@ha
	la		3, .STR1@l(3)
	lis		4, .STR2@ha
	la		4, .STR2@l(4)
	li		5, 0x23	# '#'
	li		6, -999
	lis		7, 0xffff
	ori		7, 7, 0xffff
	lis		8, 0xdead
	ori		8, 8, 0xbeef
	bl		printf
	
	# return 0
	li		0, 0
	mtlr	0
	blr
