.text
.globl _start
_start:
  c.li x31, 0x17
  c.li a0, 2
  c.slli a0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add a0, a4
  c.li a4, 4
  c.slli a4, 4
  c.add a0, a4
  .2byte 0xe0a7
  cm.jt 0
  c.li a5, 0
.Ltarget:
  c.li a4, 1
  c.li a5, 2
  c.slli a5, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a5, a3
  c.sw a4, 0(a5)
1:
  c.j 1b

.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
.align 6
table:
  .word .Ltarget
