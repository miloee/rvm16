# RUN: llvm-mc -triple=riscv32 -mattr=+m,+zc16 -show-encoding %s | FileCheck %s
# RUN: not llvm-mc -triple=riscv32 -mattr=+m %s -o /dev/null 2>&1 | FileCheck %s --check-prefix=NOZC16

# Zc16 reuses the C.FLD encoding slot (quadrant 0, funct3=001).
# The assembler accepts the compressed mnemonic and emits a 2-byte instruction.
# (This tree's llvm-mc prints the un-compressed mnemonic for -show-encoding,
# so the checks below intentionally match only the encoding bytes.)

c.mulh a0, a1
# CHECK: encoding: [0x59,0x2a]

c.mulhsu a0, a1
# CHECK: encoding: [0x5a,0x2a]

c.mulhu a0, a1
# CHECK: encoding: [0x5b,0x2a]

c.div a0, a1
# CHECK: encoding: [0x5c,0x2a]

c.divu a0, a1
# CHECK: encoding: [0x5d,0x2a]

c.rem a0, a1
# CHECK: encoding: [0x5e,0x2a]

c.remu a0, a1
# CHECK: encoding: [0x5f,0x2a]

# NOZC16: instruction requires the following: 'Zc16'
