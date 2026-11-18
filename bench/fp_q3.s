.text
.globl _start
_start:
  c.li a5, 1
  c.li t0, 31
  c.slli t0, 1
  c.addi t0, 1
  c.slli t0, 4
  c.addi t0, 8
  c.slli t0, 20
  c.fmv.w.x f0, t0
  c.fadd.s f0, f0
  c.fcvt.w.s a1, f0
  c.li t0, 1
  c.slli t0, 31
  c.li t1, 1
  c.slli t1, 8
  c.add t0, t1
  c.mv sp, t0
  c.sw a5, 0(sp)
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
