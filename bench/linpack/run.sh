#!/bin/bash
set +e
timeout 60s /home/milo/riscv-workspace/riscv-isa-sim/build/spike --isa=RV32IMFC --pc=0x80000000 /mnt/d/dsh_workspace/benchmarks/linpack/port/linpack.elf
echo "RC=$?"
