.text
.globl _start
_start:
  c.li x8, 2
  c.slli x8, 8
  c.li x14, 1
  c.slli x14, 31
  c.add x8, x14
  c.addi x8, 16
  c.li x9, 4
  c.jal .Lsum
  c.li x14, 1
  c.li x15, 2
  c.slli x15, 8
  c.li x13, 1
  c.slli x13, 31
  c.add x15, x13
  c.sw x14, 0(x15)
1:
  c.j 1b

.Lsum:
  c.li x10, 0
  .2byte 0x721F
  c.slli x9, 2
  .2byte 0x0263
.Lloop:
  c.lw x11, 0(x8)
  c.addi x8, 4
  .2byte 0x02AF
  .2byte 0x5077
.Lend:
  c.mv x8, x10
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
