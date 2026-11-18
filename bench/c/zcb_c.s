.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.lbu a1, 0(s0)
  c.lh a2, 0(s0)
  c.lhu a3, 0(s0)
  c.sb a1, 0(s0)
  c.sh a2, 0(s0)
  c.sw a1, 8(s0)
  c.sw a2, 12(s0)
  c.sw a3, 16(s0)
  c.mv a4, a1
  c.zext.b a4
  c.sw a4, 20(s0)
  c.mv a4, a1
  c.sext.b a4
  c.sw a4, 24(s0)
  c.mv a5, a1
  c.not a5
  c.sw a5, 28(s0)
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
  .byte 0x80, 0x01
  .hword 0x8001
  .space 64
