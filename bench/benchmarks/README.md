# Benchmark baseline runs

These are RV32EC+Zc* baseline runs, not RVM16-C binaries.  RVM16-C has no C
compiler, so docs/RVM16-C-Evaluation.md remains the source for RVM16-C
static-model numbers.

## Dhrystone

Source: benchmarks/dhrystone/dhrystone-master/v2.0
Port: benchmarks/dhrystone/port

Result: RC=0, self-check values correct (Int_Glob=5, Arr_2_Glob[8][7]=110,
strings and locals match).  ELF .text = 3278 B including crt0, HTIF printf and
stubs.

## CoreMark

Source: benchmarks/coremark
Port: benchmarks/coremark/port

Result: RC=0, CRC final = 0x4983, "Correct operation validated."
ELF .text = 7182 B (HAS_FLOAT=0 build).  ITERATIONS=10 but the run reports 20
iterations; the clock/timer is a deterministic stub, so timing is not wall
time.

## Linpack

Source: /home/milo/bench/linpackc.new, converted to single precision.
Port: bench/linpack (mirror of benchmarks/linpack/port)

Result: RC=0 at n=50, KFLOPS 5.00.  ELF .text = 4588 B.  The clock is a
deterministic stub; this validates the port and output path, not real
performance.
