# RVM16-C Status and Release 0.1

Date: 2026-11-18

## What is verified

- Spike-C (D:/dsh_workspace/spike-c):
  - FIR 26 B, x8=70, RC=0;
  - sum 20 B, x8=10, RC=0;
  - GP load 5/7, x8=12;
  - PC literal x8=0x12345678;
  - Zcmp cm.push {ra,s0-s7}, -48 / cm.pop, x10=7.
- LLVM MC:
  - C mnemonics under +zc16q3: c.addc/c.bnec/c.lwgc/c.lwpc/c.lwc/...;
  - branch label fixups fixup_riscv_zvmc_branch4/7;
  - FIR/sum assemble with .Lloop/.Lend, 26/20 B, run on Spike-C 70/10;
  - patch: patches/llvm/0003-RISCV-Zvmc-MC.patch.
- Evaluation:
  - Dhrystone model 2508 -> 1906 B (-24%; ~2026 with stubs);
  - CoreMark core model 6398 -> 6316 B (-1.3%);
  - stack 6.2% / 11.7%; trampoline model 7/12, 46/80;
  - block-count bound: C allocation (ALU3/branch3/GP1/LDST1) optimal on all 7 files.
- Docs:
  - docs/RVM16-C-Manual.adoc + HTML;
  - docs/RVM16-C-Evaluation.md;
  - docs/Zhihu-RVM16-C.md + figs.

## Baseline benchmark runs

- Dhrystone: RV32EC+Zc* code runs on Spike RV32IMC, RC=0, .text 2206 B.
- CoreMark: RV32EC+Zc* code runs on Spike RV32IMC, RC=0, .text 6338 B
  (ITERATIONS=10 but timer stubbed; timing not meaningful).
- These are baseline runs, not RVM16-C binaries.
- Linpack: double precision, RVM16-C F32-only; not run.

## What is not done

- Full LLVM code generator/Clang ABI/libc: only MC exists.
- Dhrystone/CoreMark are model-based, not compiled RVM16-C binaries.
- Linpack is double precision and cannot run on F32-only RVM16-C; a
  single-precision port is required.
- GitHub remote push and Zhihu publishing need user credentials.

## Reproduce

Spike-C FIR/sum:
  wsl -d Ubuntu -- bash /mnt/d/dsh_workspace/_tmp_fir_sum_c.sh

LLVM MC FIR/sum:
  wsl -d Ubuntu -- bash /mnt/d/dsh_workspace/_tmp_run_llvm_c.sh

Model:
  wsl -d Ubuntu -- python3 /mnt/d/dsh_workspace/rva-e/tools/model_c.py     /mnt/d/dsh_workspace/benchmarks/dhrystone/.../dhry_pack_1.s     /mnt/d/dsh_workspace/benchmarks/coremark/obj-c/core_main.s ...

Block bound:
  wsl -d Ubuntu -- python3 /mnt/d/dsh_workspace/rva-e/tools/block_bound.py ...

## 2026-11-18 update

- F32: all 20 instructions executed on Spike-C with expected values.
- SYS: ecall/ebreak/mret tested with a trap handler; fence/fence.i pass.
- CSR: csrw/csrr/csrs/csrc pass.
- CoreMark: seeds 0, CRC final 0x4983, "Correct operation validated", RC=0.
- Linpack float: still timing out; not validated.
