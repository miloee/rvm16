.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li s1, 4
  c.jal .Lsum
  c.li a4, 1
  c.li a5, 2
  c.slli a5, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a5, a3
  c.sw a4, 0(a5)
1:
  c.j 1b

.globl sum
sum:
.Lsum:
  c.li a0, 0
  c.blezc s1, .Lend
  c.slli s1, 2
  c.addc s1, s0
.Lloop:
  c.lwc a1, 0, s0
  c.addi s0, 4
  c.addc a0, a1
  c.bnec s0, s1, .Lloop
  .Lend:
c.mv s0, a0
  c.jr ra
.size sum, .-sum

.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
x:
  .word 1, 2, 3, 4
