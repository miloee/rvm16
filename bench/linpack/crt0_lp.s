.section .text.start
.globl _start
_start:
  la sp, _stack_top
  li t0, 0x6000
  csrw mstatus, t0
  call main
  li a0, 1
  la t0, tohost
  sw a0, 0(t0)
1:
  j 1b
