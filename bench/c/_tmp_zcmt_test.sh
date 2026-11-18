#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
mkdir -p "$D"
cd "$D"
cat > zcmt_c.s <<'EOF'
.text
.globl _start
_start:
  c.li x7, 0x17
  c.li a0, 2
  c.slli a0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add a0, a4
  c.li a4, 4
  c.slli a4, 4
  c.add a0, a4
  .2byte 0xe0a7
  cm.jt 0
  c.li a5, 0
.Ltarget:
  c.li a4, 1
  c.li a5, 2
  c.slli a5, 8
  c.li a3, 1
  c.slli a3, 31
  c.add a5, a3
  c.sw a4, 0(a5)
1:
  c.j 1b

.data
.globl tohost
.align 3
tohost:
  .zero 8
fromhost:
  .zero 8
.align 6
table:
  .word .Ltarget
EOF
$B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb,+zcmp,+zcmt,+zcf,+zc16q3 -filetype=obj -o zcmt_c.o zcmt_c.s
riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o zcmt_c.elf zcmt_c.o
timeout 5s /mnt/d/dsh_workspace/spike-c/build/spike --isa=RV32IMFC_Zcb_Zcmp_Zcmt_Zcf_Zc16 --pc=0x80000100 --log-commits zcmt_c.elf > zcmt_c.log 2>&1
echo "RC=$?"
grep -E 'mem 0x80000200 0x00000001|x31 0x00000017' zcmt_c.log | tail -3
