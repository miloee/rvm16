#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
SP=/home/milo/spike-c-build-2/spike
cd "$D"
cat > csr2_c.s <<'EOF'
.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.li x7, 26
  c.slli x7, 5
  c.li a0, 5
  .2byte 0xe0ab
  c.li a0, 1
  .2byte 0xe0af
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
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb -filetype=obj -o csr2_c.o csr2_c.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o csr2_c.elf csr2_c.o
set +e
timeout 5s "$SP" --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits csr2_c.elf > csr2_c.log 2>&1
echo "RC=$?"
grep -E 'mem 0x8000021' csr2_c.log | sed -E 's/.*mem /mem /'
