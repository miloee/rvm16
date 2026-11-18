.text
.globl _start
_start:
.Lcode:
  .2byte 0x380B
  c.j .Ldone
  c.nop
  c.nop
  .word 0x12345678
.Ldone:
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
