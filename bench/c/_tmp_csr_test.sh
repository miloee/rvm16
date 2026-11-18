#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
SP=/home/milo/spike-c-build-2/spike
cd "$D"
cat > csr_c.s <<'EOF'
.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li x7, 0x17
  c.li a0, 31
  .2byte 0xe0a7
  .2byte 0xe0b3
  c.sw a1, 0(s0)
  .2byte 0xf013
  .2byte 0xf017
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
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb -filetype=obj -o csr_c.o csr_c.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o csr_c.elf csr_c.o
set +e
timeout 5s "$SP" --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits csr_c.elf > csr_c.log 2>&1
echo "RC=$?"
grep -E 'mem 0x8000021|mem 0x8000022' csr_c.log | sed -E 's/.*mem /mem /'
