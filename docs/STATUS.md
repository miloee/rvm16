# RVM16-C Status

Date: 2026-11-18

## Verified instruction groups (Spike-C)

Spike-C source: D:/dsh_workspace/spike-c, mirrored at spike-c/ in this repo.

- ALU-12: add/sub/and/or/xor/sll/srl/sra/slt/sltu, expected values checked.
- M: mulh/mulhsu/mulhu/div/divu/rem/remu, expected values checked.
- F32: all 20 ops; fadd/fsub/fmul/fdiv/fsqrt/fmin/fmax/fsgnj/fsgnjn/fsgnjx/
  feq/flt/fle/fcvt.s.w/fcvt.w.s/fclass/fmv.x.w/fmv.w.x/flw/fsw.
- CSR: csrw/csrr/csrs/csrc (csrw/csrr with mscratch, csrs/csrc bit set/clear).
- SYS: ecall/ebreak via trap handler, mret, fence, fence.i, wfi via CLINT
  timer interrupt.
- Zcb: lbu/lh/lhu/sb/sh/zext.b/h/sext.b/h/not, RC=0.  sext.b/h require Zbb;
  zext.w requires Zba on RV32 and is optional.
- FIR 26 B (x8=70), sum 20 B (x8=10), GP/PC, Zcmp, Zcmt, Zcf encodings.

## Benchmarks

These are RV32EC+Zc* baseline binaries, not RVM16-C binaries.  RVM16-C has no
C compiler, so its Dhrystone/CoreMark numbers are still static-model results.

| Benchmark | Result | Notes |
|---|---|---|
| Dhrystone | RC=0, self-check values correct | .text about 3.3 KB incl. crt0/printf/stubs |
| CoreMark | RC=0, CRC final 0x4983, "Correct operation validated" | seeds 0; clock/timer stubs |
| Linpack | RC=0, KFLOPS 5.00, n=50 | float port; clock is a deterministic stub |

## Repository

- https://github.com/miloee/rvm16
- main branch and tags rvm16c-v0.1, spike-c-v0.1
- spike-c/ complete source overlay; bench/c/ instruction tests; bench/linpack/
  float port; docs/RVM16-C-Manual.adoc + HTML.

## Not done

- Full LLVM code generator/Clang ABI/libc.
- RVM16-C-compiled Dhrystone/CoreMark/Linpack binaries.
- Every individual RVC encoding is not enumerated; inherited RVC is exercised
  through the programs and the block tests.
- Zbb/Zba are not in the baseline profile; c.sext.b/h and c.zext.w are
  conditional on them.

## Reproduce

- Instruction tests: bench/c/test_*.sh and their .s programs.
- Linpack: bench/linpack/build.sh, bench/linpack/run.sh.
- Dhrystone/CoreMark ports: bench/benchmarks/README.md.
- Model: tools/model_c.py; block bound: tools/block_bound.py.
