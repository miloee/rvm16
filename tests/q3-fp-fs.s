.text
.globl _start
_start:
  c.li a5, 1
  c.li a0, 6
  c.slli a0, 12
  .2byte 0xe1a7
  c.li t0, 31
  c.slli t0, 1
  c.addi t0, 1
  c.slli t0, 4
  c.addi t0, 8
  c.slli t0, 20
  c.fmv.w.x f0, t0
  c.fadd.s f0, f0
  c.fcvt.w.s a1, f0
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
