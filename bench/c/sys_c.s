.text
.globl _start
_start:
  c.j main
  .org 0x10
handler:
  c.li x7, 13
  c.slli x7, 6
  .2byte 0xe0a3
  c.mv s0, a0
  c.lw a1, 0(s0)
  c.addi a1, 1
  c.sw a1, 0(s0)
  c.li x7, 13
  c.slli x7, 6
  c.addi x7, 1
  .2byte 0xe0a3
  c.addi a0, 2
  .2byte 0xe0a7
  .2byte 0xf00b
  .org 0x40
main:
  c.li a0, 2
  c.slli a0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add a0, a4
  c.addi a0, 16
  c.li x7, 13
  c.slli x7, 6
  .2byte 0xe0a7
  c.li a0, 0x11
  c.slli a0, 4
  c.li a4, 1
  c.slli a4, 31
  c.add a0, a4
  c.li x7, 12
  c.slli x7, 6
  c.addi x7, 5
  .2byte 0xe0a7
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li a1, 0
  c.sw a1, 0(s0)
  .2byte 0xf003
  .2byte 0xf007
  c.li a5, 1
  c.li a4, 2
  c.slli a4, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a4, a3
  c.sw a5, 0(a4)
1:
  c.j 1b
.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
  .space 64
