#!/usr/bin/env python3
"""RVA-E16 Q3 allocation checker."""

Q3_PATTERNS = 1 << 14
BLOCK_PATTERNS = 1 << 10

BLOCKS = [
    (0x0, "CR3 sll",  [("rd",5),("rs2",5)], 1),
    (0x1, "CR3 srl",  [("rd",5),("rs2",5)], 1),
    (0x2, "CR3 sra",  [("rd",5),("rs2",5)], 1),
    (0x3, "CR3 slt",  [("rd",5),("rs2",5)], 1),
    (0x4, "CR3 sltu", [("rd",5),("rs2",5)], 1),
    (0x5, "CA3 M",    [("funct",3),("rd",3),("rs2",3),("spare",1)], 8),
    (0x6, "CI3",      [("funct",2),("rd",4),("imm",4)], 4),
    (0x7, "LD/ST A",  [("funct",2),("reg",3),("base",2),("off",3)], 4),
    (0x8, "LD/ST B",  [("funct",2),("reg",3),("base",2),("off",3)], 4),
    (0x9, "FP A",     [("funct",2),("fd",3),("fs2",3),("spare",2)], 4),
    (0xA, "FP B",     [("funct",2),("fd",3),("fs2",3),("spare",2)], 4),
    (0xB, "FP C",     [("funct",2),("fd",3),("fs2",3),("spare",2)], 4),
    (0xC, "FP D",     [("funct",2),("fd",3),("fs2",3),("spare",2)], 4),
    (0xD, "FP E",     [("funct",2),("fd",3),("fs2",3),("spare",2)], 4),
    (0xE, "CSR3",     [("csr",4),("reg",4),("op",2)], 4),
    (0xF, "SYS",      [("imm",10)], 8),
]

def check_blocks():
    seen = set()
    total = 0
    for f4, name, fields, ops in BLOCKS:
        assert f4 not in seen, "duplicate f4 %x" % f4
        seen.add(f4)
        width = sum(w for _, w in fields)
        assert width == 10, "%s: fields sum to %d, not 10" % (name, width)
        total += BLOCK_PATTERNS
    assert total == Q3_PATTERNS, "blocks cover %d, not %d" % (total, Q3_PATTERNS)
    print("blocks: %d, patterns: %d (ok)" % (len(BLOCKS), total))

def enc(f4, fixed_bits, fixed_mask):
    match = (f4 << 12) | fixed_bits | 0b11
    mask = 0xF000 | fixed_mask | 0x0003
    return match, mask

# f4, fixed payload bits, fixed payload mask
SLICE = [
    ("c.sll",  enc(0x0, 0x000, 0x000)),
    ("c.slt",  enc(0x3, 0x000, 0x000)),
    ("c.mul",  enc(0x5, 0x000, 0xE00)),   # funct3 = 0
    ("c.xori", enc(0x6, 0xC00, 0xC00)),   # funct2 = 3, rd/imm free
    ("c.lw",   enc(0x7, 0x000, 0xC00)),   # funct2 = 0
    ("c.sw",   enc(0x7, 0x400, 0xC00)),   # funct2 = 1
]

def check_slice():
    out = []
    for name, (match, mask) in SLICE:
        assert (match & mask) == match, "%s: match=0x%04x mask=0x%04x" % (name, match, mask)
        out.append((name, match, mask))
    for i in range(len(out)):
        for j in range(i+1, len(out)):
            n1, m1, k1 = out[i]
            n2, m2, k2 = out[j]
            common = k1 & k2
            if ((m1 ^ m2) & common) == 0:
                raise AssertionError("overlap: %s and %s" % (n1, n2))
    for n, m, k in out:
        print("%-8s match=0x%04x mask=0x%04x" % (n, m, k))

if __name__ == "__main__":
    check_blocks()
    print("--- vertical slice ---")
    check_slice()
