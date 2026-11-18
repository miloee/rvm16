# Spike patch: Zc16.M

Apply with:

```bash
cd riscv-isa-sim
patch -p1 < ../0001-Add-Zc16-16-bit-multiply-divide.patch
```

## One manual step

The patch adds `EXT_ZC16` to `riscv/isa_parser.h`, but this workspace's Spike
tree does not contain `riscv/isa_parser.cc` (the file is absent from the
checkout), so the extension-string entry could not be patched here.  In a
clean Spike checkout, add the entry to the multi-letter extension table in
`riscv/isa_parser.cc`:

```cpp
{ "zc16", EXT_ZC16 },
```

and, if your tree enables Zc* extensions from Zca, add:

```cpp
proc->set_extension_enable(EXT_ZC16, proc->extension_enabled(EXT_ZCA));
```

in the same place that `EXT_ZCB` and `EXT_ZCMP` are enabled.

Without that entry, `--isa=...zc16` will not be accepted and every Zc16
instruction will take an illegal-instruction trap.

## What the patch contains

| File | Change |
|---|---|
| `riscv/encoding.h` | 7 `MATCH_C_*`/`MASK_C_*` pairs, 7 `DECLARE_INSN` |
| `riscv/decode.h` | `cm_rd()` / `cm_rs2()` (bits 12:8 and 7:3) |
| `riscv/isa_parser.h` | `EXT_ZC16` enum value |
| `riscv/riscv.mk.in` | add the 7 instruction bodies to `riscv_insn_ext_c` |
| `riscv/insns/c_*.h` | 7 new instruction bodies |

## Build and test

```bash
./configure --prefix=$PWD/install
make -j20
make install

# assemble a test with the patched LLVM
printf '.text\n.globl _start\n_start:\n  li a0, 0x80000000\n  li a1, 0x80000000\n  c.mulh a0, a1\n  csrr a0, mscratch\n' > zc16.S
```

A full functional test needs an ELF loader and a trap handler; the simplest
path is to add the seven instructions to the RISC-V tests or to run the
LLVM-generated object under Spike's `--log-commits` and check the register
write.

## Expected encodings

```
c.mulh   a0, a1 -> 0x2a59
c.mulhsu a0, a1 -> 0x2a5a
c.mulhu  a0, a1 -> 0x2a5b
c.div    a0, a1 -> 0x2a5c
c.divu   a0, a1 -> 0x2a5d
c.rem    a0, a1 -> 0x2a5e
c.remu   a0, a1 -> 0x2a5f
```
