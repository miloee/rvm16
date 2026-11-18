#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
SP=/home/milo/spike-c-build-2/spike
cd "$D"
cat > wfi3.s <<'EOF'
.text
.globl _start
_start:
  c.j main
  .org 0x10
handler:
  c.li x7, 13
  c.slli x7, 6
  .2byte 0xe0a3
  c.mv s0, a0
  c.lw a1, 0(s0)
  c.addi a1, 1
  c.sw a1, 0(s0)
  c.li t0, 2
  c.slli t0, 24
  c.li t1, 4
  c.slli t1, 12
  c.add t0, t1
  c.mv s1, t0
  c.li a2, -1
  c.sw a2, 0(s1)
  .2byte 0xf00b
  .org 0x40
main:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.mv a0, s0
  c.addi a0, 16
  c.li x7, 13
  c.slli x7, 6
  .2byte 0xe0a7
  c.li a0, 0x11
  c.slli a0, 4
  c.li a4, 1
  c.slli a4, 31
  c.add a0, a4
  c.li x7, 12
  c.slli x7, 6
  c.addi x7, 5
  .2byte 0xe0a7
  c.li x7, 12
  c.slli x7, 6
  c.addi x7, 5
  .2byte 0xe0a3
  c.sw a0, 0(s0)
  c.li a0, 8
  c.li x7, 12
  c.slli x7, 6
  .2byte 0xe0a7
  c.li x7, 12
  c.slli x7, 6
  .2byte 0xe0a3
  c.sw a0, 4(s0)
  c.li a0, 8
  c.slli a0, 4
  c.li x7, 12
  c.slli x7, 6
  c.addi x7, 4
  .2byte 0xe0a7
  c.li x7, 12
  c.slli x7, 6
  c.addi x7, 4
  .2byte 0xe0a3
  c.sw a0, 8(s0)
  c.li t0, 2
  c.slli t0, 24
  c.li t1, 4
  c.slli t1, 12
  c.add t0, t1
  c.mv s1, t0
  c.li a2, 0
  c.sw a2, 0(s1)
  .2byte 0xf00f
  c.li a0, 24
  c.sw a0, 12(s0)
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
  .space 64
EOF
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb -filetype=obj -o wfi3.o wfi3.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o wfi3.elf wfi3.o
set +e
timeout 5s "$SP" --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits wfi3.elf > wfi3.log 2>&1
echo "RC=$?"
grep -E 'mem 0x800002' wfi3.log | sed -E 's/.*mem /mem /'
