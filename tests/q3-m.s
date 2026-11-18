.text
.globl _start
_start:
  c.li a5, 1
  c.li a0, 7
  c.li a1, 2
  .2byte 0x589b
  .2byte 0x5c9b
  c.li s0, 1
  c.slli s0, 31
  c.li a4, 1
  c.slli a4, 8
  c.add s0, a4
  c.sw a5, 0(s0)
1:
  c.j 1b
.data
.globl tohost
.align 3
tohost:
  .zero 8
.globl fromhost
fromhost:
  .zero 8
