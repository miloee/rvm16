#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
cd "$D"
for f in fir_llvm sum_llvm; do
  $B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb,+zc16q3 -filetype=obj -o "$f".o "$f".s
  riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o "$f".elf "$f".o
  echo -n "$f "
  riscv64-linux-gnu-nm -S "$f".o | grep -E ' fir$| sum$' | awk '{print $2, $3}'
  timeout 5s /mnt/d/dsh_workspace/spike-c/build/spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits "$f".elf > "$f".log 2>&1
  echo "RC=$?"
  grep -E 'x8  0x000000(46|0a)' "$f".log | tail -1
done
