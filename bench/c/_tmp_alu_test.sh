#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
mkdir -p "$D"
cd "$D"
cat > alu_c.s <<'EOF'
.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li a0, 6
  c.li a1, 3
  c.andc a0, a1
  c.sw a0, 0(s0)
  c.li a0, 6
  c.orc a0, a1
  c.sw a0, 4(s0)
  c.li a0, 6
  c.xorc a0, a1
  c.sw a0, 8(s0)
  c.li a0, 1
  c.sllc a0, a1
  c.sw a0, 12(s0)
  c.li a0, 8
  c.srlc a0, a1
  c.sw a0, 16(s0)
  c.li a0, -8
  c.srac a0, a1
  c.sw a0, 20(s0)
  c.li a0, 1
  c.sltc a0, a1
  c.sw a0, 24(s0)
  c.li a0, 1
  c.sltuc a0, a1
  c.sw a0, 28(s0)
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
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb,+zc16q3 -filetype=obj -o alu_c.o alu_c.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o alu_c.elf alu_c.o
timeout 5s /home/milo/spike-c-build-2/spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits alu_c.elf > alu_c.log 2>&1
echo "RC=$?"
grep -E 'mem 0x8000021|mem 0x8000022' alu_c.log | sed -E 's/.*mem /mem /' 
