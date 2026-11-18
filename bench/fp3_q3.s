.text
.globl _start
_start:
  c.li a5, 1
  c.li t0, 16
  c.slli t0, 2
  c.slli t0, 4
  c.addi t0, 8
  c.slli t0, 20
  .2byte 0xd417
  c.li t0, 1
  c.slli t0, 31
  c.li t1, 2
  c.slli t1, 8
  c.add t0, t1
  c.mv sp, t0
  .2byte 0xdc23
  .2byte 0xd823
  .2byte 0xa003
  .2byte 0xc82f
  c.li t0, 1
  c.slli t0, 31
  c.li t1, 1
  c.slli t1, 8
  c.add t0, t1
  c.mv sp, t0
  .2byte 0x8fc3
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
  .space 0x200
