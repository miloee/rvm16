#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/c-tests
mkdir -p "$D"
cd "$D"

cat > fir_c.s <<'EOF'
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
EOF

cat > sum_c.s <<'EOF'
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
EOF

for f in fir_c sum_c; do
  $B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb -filetype=obj -o "$f".o "$f".s
  riscv64-linux-gnu-ld -m elf32lriscv -T /home/milo/q3test/link_stack.ld -o "$f".elf "$f".o
  echo -n "$f "
  riscv64-linux-gnu-size -A "$f".o | grep -E "^\.text" | awk '{print $2}'
done

for f in fir_c sum_c; do
  timeout 5s /mnt/d/dsh_workspace/spike-c/build/spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000100 --log-commits "$f".elf > "$f".log 2>&1
  echo "$f RC=$?"
  grep -E "x8 0x000000(46|0a)" "$f".log | tail -1
done
