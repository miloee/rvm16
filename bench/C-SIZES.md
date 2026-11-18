# C code-size: clang -O2 vs naive Expand16

These are real C functions compiled with clang -O2 for RV32IMAF_C, then
translated by tools/expand16.py (the standalone prototype, not the LLVM
post-RA pass).  Sizes are .text bytes for the function body.

| Function | RV32IMAF_C | RVM16 (naive) | Delta |
|---|---:|---:|---:|
| fir (loop, 2 loads, mul) | 32 | 38 | +18.8% |
| sum (loop, 1 load) | 24 | 30 | +25.0% |
| call (add + f, stack/ra) | 24 | 18 | -25.0% |

RVM16 pointer ABI (the first two pointer arguments arrive in s0/s1, so the
base registers are populated by the calling convention rather than by an
entry copy):

| Function | RV32IMAF_C | RVM16 (s0/s1 ABI) | Delta |
|---|---:|---:|---:|
| fir | 32 | 34 | +6.3% |
| sum | 24 | 28 | +16.7% |

The naive translator does not yet exploit the ISA:

- every load/store with a pointer in a0/a1 needs c.mv s0/s1, base first;
- three-address ALU needs c.mv for the 2-address form;
- conditional branches expand to compare + c.beqz/c.bnez, because Q3 has no
  flags and RVC only compares against zero.

The hand-written kernels (ALU/FP) still show 10-29% reductions, but the C
result is mixed.  A real compiler needs pointer arguments in s0/s1 (the
Q3 base registers), a peephole for redundant c.mv, and possibly a Q3
two-register conditional branch block.  This is the key code-size finding
to report honestly, not a bug in the translator.
