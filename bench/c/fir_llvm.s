.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.mv s1, s0
  c.addi s1, 16
  c.li a0, 4
  c.jal .Lfir
  c.li a4, 1
  c.li a5, 2
  c.slli a5, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a5, a3
  c.sw a4, 0(a5)
1:
  c.j 1b

.globl fir
fir:
.Lfir:
  c.li a1, 0
  c.blezc a0, .Lend
  c.slli a0, 2
  c.addc a0, s1
.Lloop:
  c.lwc a2, 0, s0
  c.lwc a3, 0, s1
  c.addi s1, 4
  c.mul a2, a3
  c.addc a1, a2
  c.addi s0, 4
  c.bnec s1, a0, .Lloop
  .Lend:
c.mv s0, a1
  c.jr ra
.size fir, .-fir

.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
x:
  .word 1, 2, 3, 4
h:
  .word 5, 6, 7, 8
