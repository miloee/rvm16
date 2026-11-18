#!/bin/bash
set +e
P=$(cd "$(dirname "$0")" && pwd)
timeout 60s /home/milo/riscv-workspace/riscv-isa-sim/build/spike --isa=RV32IMFC --pc=0x80000000 "$P/linpack.elf"
echo "RC=$?"
