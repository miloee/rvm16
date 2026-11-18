.text
.globl _start
_start:
  c.li x3, 2
  c.slli x3, 8
  c.li x14, 1
  c.slli x14, 31
  c.add x3, x14
  .2byte 0x3013
  .2byte 0x3117
  c.add x8, x9
  c.li x14, 1
  c.li x15, 2
  c.slli x15, 8
  c.li x13, 1
  c.slli x13, 31
  c.add x15, x13
  c.sw x14, 0(x15)
1:
  c.j 1b

.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
g0:
  .word 5
g1:
  .word 7
