.text
.globl _start
_start:
  li t0, 0x6000
  csrs mstatus, t0
  li a5, 1
  li t0, 31
  slli t0, t0, 1
  addi t0, t0, 1
  slli t0, t0, 4
  addi t0, t0, 8
  slli t0, t0, 20
  fmv.w.x f0, t0
  fadd.s f0, f0, f0
  fcvt.w.s a1, f0
  li t0, 1
  slli t0, t0, 31
  li t1, 1
  slli t1, t1, 8
  add t0, t0, t1
  mv sp, t0
  sw a5, 0(sp)
1: j 1b
.data
.globl tohost
.align 3
tohost: .zero 8
.globl fromhost
fromhost: .zero 8
