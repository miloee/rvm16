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
  c.li t1, 1
  c.slli t1, 30
  c.fmv.w.x f0, t0
  c.fmv.w.x f1, t1
  c.fadd.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fsub.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fmul.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fdiv.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t1
  c.fadd.s f0, f0
  c.fsqrt.s f0, f0
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fmin.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fmax.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fsgnj.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fsgnjn.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fsgnjx.s f0, f1
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.feq.s f0, f1
  c.mv a0, t2
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.flt.s f0, f1
  c.mv a0, t2
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fle.s f0, f1
  c.mv a0, t2
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.li a0, 3
  c.fcvt.s.w f0, a0
  c.fsw f0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t1
  c.fcvt.w.s a0, f0
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.fmv.w.x f0, t0
  c.fclass.s a0, f0
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.fmv.x.w a0, f0
  c.sw a0, 0(s1)
  c.addi s1, 4
  c.mv a2, t0
  c.sw a2, 0(s1)
  c.flw f0, 0(s1)
  c.fsw f0, 1(s1)
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
  .space 128
