.text
.globl _start
_start:
  c.li sp, 2
  c.slli sp, 8
  c.li a4, 1
  c.slli a4, 31
  c.add sp, a4
  c.li a4, 3
  c.slli a4, 8
  c.add sp, a4
  c.li a0, 3
  c.li a1, 4
  c.jal .Lf
  c.li a5, 1
  c.li a4, 2
  c.slli a4, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a4, a3
  c.sw a5, 0(a4)
1:
  c.j 1b
.Lf:
  cm.push {ra, s0-s7}, -48
  c.addc a0, a1
  cm.pop {ra, s0-s7}, 48
  ret
.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
  .space 0x200
