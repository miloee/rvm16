.text
.globl _start
_start:
  c.li a5, 1
  c.li a0, 6
  c.slli a0, 12
  .2byte 0xe8a7
  .2byte 0xe8b3
  c.li a0, 1
  .2byte 0xe8ab
  .2byte 0xe8b3
  .2byte 0xe8af
  .2byte 0xe8b3
  .2byte 0xefc3
  c.li a0, 6
  c.slli a0, 12
  .2byte 0xe1a7
  .2byte 0xe1b3
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
