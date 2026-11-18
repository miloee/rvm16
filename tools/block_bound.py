#!/usr/bin/env python3
"""Bounded block-count optimization for RVM16-C.

Free blocks after mandatory FP/M/CSR/SYS/LDST: 8.  Enumerate ALU blocks,
branch blocks, GP/PC block, and extra LD/ST blocks; choose the allocation
with the lowest modeled bytes.  This bounds the block-count choice, not the
full opcode assignment.
"""
import sys

ALU = ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu']
BR = ['bne', 'blt', 'blez']


def counts(path):
    alu = {k: 0 for k in ALU}
    br = {k: 0 for k in BR}
    gp = 0
    st = 0
    ld = 0
    for raw in open(path):
        line = raw.split('#')[0].strip()
        if not line or line.endswith(':') or line.startswith('.'):
            continue
        p = line.replace(',', ' ').split()
        m = p[0]
        ops = p[1:]
        if m in ALU and len(ops) >= 3:
            alu[m] += 1
        if m in BR:
            br[m] += 1
        if m in ('lw', 'sw'):
            ld += 1
        if '%hi(' in line:
            if '.L.str' in line:
                st += 1
            elif ('Glob' in line or 'Int_' in line or 'Ch_' in line or 'Ptr_' in line):
                gp += 1
    return alu, br, gp, st, ld


def cost(alu, br, gp, st, ld, a, b, g, l):
    # cover the most frequent ALU opcodes with 4*a slots
    vals = sorted(alu.values(), reverse=True)
    covered = sum(vals[:4 * a])
    total = sum(vals)
    c = (covered * 2) + ((total - covered) * 4)
    # branches: each block covers one type
    bvals = sorted(br.values(), reverse=True)
    bcov = sum(bvals[:b])
    btot = sum(bvals)
    c += bcov * 2 + (btot - bcov) * 6
    # GP/PC
    if g:
        c += (gp + st) * 2
    else:
        c += gp * 12 + st * 6
    # LD/ST
    c += ld * (2 if l else 4)
    return c


def solve(alu, br, gp, st, ld):
    best = None
    for a in range(0, 9):
        for b in range(0, 4):
            for g in range(0, 2):
                l = 8 - a - b - g
                if l < 0 or l > 1:
                    continue
                c = cost(alu, br, gp, st, ld, a, b, g, l)
                if best is None or c < best[0]:
                    best = (c, a, b, g, l)
    cC = cost(alu, br, gp, st, ld, 3, 3, 1, 1)
    return best, cC


if __name__ == '__main__':
    for p in sys.argv[1:]:
        alu, br, gp, st, ld = counts(p)
        best, cC = solve(alu, br, gp, st, ld)
        print('%s alu=%s br=%s gp=%d str=%d ldst=%d' % (p.split('/')[-1], alu, br, gp, st, ld))
        print('  best=%d alloc(a=%d,b=%d,g=%d,l=%d)  C=%d' % (best[0], best[1], best[2], best[3], best[4], cC))
