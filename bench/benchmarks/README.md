# Benchmark baseline runs

These are RV32EC+Zc* baseline runs, not RVM16-C binaries.  The RVM16-C
numbers in docs/RVM16-C-Evaluation.md are static-model results.

## Dhrystone

Source: benchmarks/dhrystone/dhrystone-master/v2.0
Port: benchmarks/dhrystone/port
Build: wsl -d Ubuntu -- bash .../port/build.sh
Run:   wsl -d Ubuntu -- bash .../port/run.sh

Result: RC=0, ELF .text = 2206 B (including crt0/stubs).
Note: code compiled for rv32emc_zcb_zcmp_zcmt; standard Spike lacks E, so it
runs with --isa=RV32IMC_Zcb_Zcmp_Zcmt.  printf is a no-op and scanf returns 10.

## CoreMark

Source: benchmarks/coremark
Port: benchmarks/coremark/port
Build: wsl -d Ubuntu -- bash .../port/build.sh
Run:   wsl -d Ubuntu -- bash .../port/run.sh

Result: RC=0, ELF .text = 6338 B (including crt0/stubs).
Note: ITERATIONS=10, but time_in_secs() is stubbed to 10 so CoreMark runs the
minimum iteration count; timing is not meaningful.

## Linpack

Source: /home/milo/bench/linpackc.new (double precision).
Not run: RVM16-C is F32-only; standard Linpack needs D.  A single-precision
port would be a different benchmark.
