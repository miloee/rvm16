.text
.globl _start
_start:
  c.li a0, 3
  c.li a1, 4
  c.sll a0, a1
  c.li a3, 6
  c.mul a3, a0
  c.xori a0, 15
  c.li a5, 1
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
