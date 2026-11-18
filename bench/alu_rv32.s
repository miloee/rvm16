.text
.globl _start
_start:
  li a5, 1
  li a0, 3
  li a1, 4
  sll a0, a0, a1
  li a3, 6
  mul a3, a3, a0
  li a2, 5
  slt a0, a0, a2
  xori a0, a0, 15
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
