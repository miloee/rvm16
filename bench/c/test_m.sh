#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
SP=/home/milo/spike-c-build-2/spike
cd "$D"
cat > m_c.s <<'EOF'
.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li a0, 7
  c.li a1, 2
  .2byte 0x429b
  c.sw a0, 0(s0)
  c.li a0, 7
  .2byte 0x449b
  c.sw a0, 4(s0)
  c.li a0, 7
  .2byte 0x469b
  c.sw a0, 8(s0)
  c.li a0, 7
  .2byte 0x489b
  c.sw a0, 12(s0)
  c.li a0, 7
  .2byte 0x4a9b
  c.sw a0, 16(s0)
  c.li a0, 7
  .2byte 0x4c9b
  c.sw a0, 20(s0)
  c.li a0, 7
  .2byte 0x4e9b
  c.sw a0, 24(s0)
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
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb -filetype=obj -o m_c.o m_c.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o m_c.elf m_c.o
set +e
timeout 5s "$SP" --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits m_c.elf > m_c.log 2>&1
echo "RC=$?"
grep -E 'mem 0x8000021|mem 0x8000022' m_c.log | sed -E 's/.*mem /mem /'
