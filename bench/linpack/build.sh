#!/bin/bash
set -e
B=/home/milo/rvv-alt/llvm-project/build/bin
D=/mnt/d/dsh_workspace/benchmarks/linpack
P=$D/port
ST=/mnt/d/dsh_workspace/benchmarks/stubs
DP=/mnt/d/dsh_workspace/benchmarks/dhrystone/port
mkdir -p "$P"
cd "$D"
sed -e 's/double/float/g' -e 's/fabs(/fabsf(/g' -e 's/sqrt(/sqrtf(/g' -e 's/while (linpack(nreps,arsize)<10.)/linpack(nreps,arsize);/' -e 's/arsize=atoi(buf);/arsize=50;/' -e 's/2\.0\*n\*n\*n/2.0f*n*n*n/g' -e 's/2\.0\*n\*n/2.0f*n*n/g' -e 's|/3\.0|/3.0f|g' -e 's/2\.\*nreps/2.0f*nreps/g' -e 's/1000\.\*/1000.0f*/g' -e 's/100\.\*/100.0f*/g' -e 's/#define PREC .*/#define PREC "Single"/' -e 's/#define BASE10DIG .*/#define BASE10DIG 7/' /home/milo/bench/linpackc.new > "$D/linpackf.c"
$B/clang --target=riscv32 -march=rv32imfc -mabi=ilp32f -O2 -ffreestanding -std=gnu89 -Wno-implicit-function-declaration -Wno-int-conversion -Wno-deprecated-non-prototype -isystem "$ST" -I. -c "$D/linpackf.c" -o "$P/linpackf.o"
$B/clang --target=riscv32 -march=rv32imfc -mabi=ilp32f -O2 -ffreestanding -isystem "$ST" -I. -c "$P/port.c" -o "$P/port.o"
$B/clang --target=riscv32 -march=rv32imfc -mabi=ilp32f -c "$P/crt0_lp.s" -o "$P/crt0.o"
$B/clang --target=riscv32 -march=rv32imfc -mabi=ilp32f -O2 -ffreestanding -c "$P/softfloat_ext.c" -o "$P/softfloat.o"
riscv64-linux-gnu-ld -m elf32lriscv -T "$P/link.ld" -o "$P/linpack.elf" "$P/crt0.o" "$P/linpackf.o" "$P/port.o" "$P/softfloat.o"
echo -n "text="; riscv64-linux-gnu-size -A "$P/linpack.elf" | awk '/^\.text/{print $2}'
