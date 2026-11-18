.text
.globl _start
_start:
  c.li x8, 2
  c.slli x8, 8
  c.li x14, 1
  c.slli x14, 31
  c.add x8, x14
  c.addi x8, 16
  c.mv x9, x8
  c.addi x9, 16
  c.li x10, 4
  c.jal .Lfir
  c.li x14, 1
  c.li x15, 2
  c.slli x15, 8
  c.li x13, 1
  c.slli x13, 31
  c.add x15, x13
  c.sw x14, 0(x15)
1:
  c.j 1b

.Lfir:
  c.li x11, 0
  .2byte 0x742B
  c.slli x10, 2
  .2byte 0x02A7
.Lloop:
  .2byte 0x8303
  .2byte 0x8353
  c.addi x9, 4
  c.mul x12, x13
  .2byte 0x02F3
  c.addi x8, 4
  .2byte 0x52AB
.Lend:
  c.mv x8, x11
  c.jr ra

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
