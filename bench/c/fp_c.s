.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li x7, 3
  c.slli x7, 8
  c.li a0, 3
  c.slli a0, 13
  .2byte 0xe0a7
  c.li t0, 31
  c.slli t0, 1
  c.addi t0, 1
  c.slli t0, 4
  c.addi t0, 8
  c.slli t0, 20
  c.fmv.w.x f0, t0
  c.fadd.s f0, f0
  c.fcvt.w.s a1, f0
  c.sw a1, 0(s0)
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
