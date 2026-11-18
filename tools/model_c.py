#!/usr/bin/env python3
"""Approximate RV32EC -> RVM16-C code-size model.

Reads clang -S output (rv32emc_zcb_zcmp_zcmt), computes the RV32EC byte size
and a heuristic RVM16-C byte size.  This is a model, not a compiler.
"""
import sys

LOW = {'x8': 8, 'x9': 9, 'x10': 10, 'x11': 11, 'x12': 12, 'x13': 13,
       'x14': 14, 'x15': 15, 's0': 8, 's1': 9, 'a0': 10, 'a1': 11,
       'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15}
BASE = {'x8', 'x9', 's0', 's1', 'sp', 'gp', 'x2', 'x3'}
BASE_RVC = {'x8', 'x9', 'x10', 'x11', 'x12', 'x13', 'x14', 'x15',
            's0', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5'}


def regno(r):
    r = r.strip()
    if r in LOW:
        return LOW[r]
    if r.startswith('x') and r[1:].isdigit():
        return int(r[1:])
    return None


def imm(s):
    s = s.strip()
    try:
        return int(s, 0)
    except Exception:
        return None


def sym_of(op):
    for tag in ('%hi(', '%lo('):
        if tag in op:
            return op.split(tag, 1)[1].split(')', 1)[0]
    return None


def classify(sym):
    if sym is None:
        return 'other'
    if ('MergedGlobals' in sym or 'Glob' in sym or 'Int_' in sym or
            'Ch_' in sym or 'Arr_' in sym or 'Ptr_' in sym):
        return 'gp'
    if '.L.str' in sym:
        return 'str'
    return 'other'


def actual_size(m, ops):
    if m.startswith('c.') or m.startswith('cm.'):
        return 2
    if m == 'li':
        v = imm(ops[-1]) if ops else None
        if v is not None and -32 <= v <= 31:
            return 2
        if v is not None and -2048 <= v <= 2047:
            return 4
        return 8
    if m in ('mv', 'beqz', 'bnez', 'j', 'ret', 'nop'):
        return 2
    if m in ('addi', 'andi', 'slli', 'srli', 'srai'):
        v = imm(ops[-1]) if ops else None
        return 2 if v is not None and -32 <= v <= 31 else 4
    if m in ('mul', 'div', 'divu', 'rem', 'remu'):
        return 2
    if m in ('call', 'tail'):
        return 4
    return 4


def c_cost(m, ops, off, labels):
    if m.startswith('c.'):
        return 2
    if m.startswith('cm.'):
        # Zcmp is part of the RVM16-C baseline: push/pop are 2 bytes.
        return 2
    if m == 'li':
        v = imm(ops[-1]) if ops else None
        return 2 if v is not None and -32 <= v <= 31 else 16
    if m in ('mv', 'beqz', 'bnez', 'j', 'ret', 'nop'):
        return 2
    if m in ('call', 'tail'):
        return 2
    if m in ('add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra',
             'slt', 'sltu'):
        if len(ops) >= 3 and (ops[0] == ops[1] or ops[0] == ops[2]):
            return 2
        return 4
    if m == 'mul':
        return 2
    if m in ('div', 'divu', 'rem', 'remu'):
        return 2
    if m == 'addi':
        v = imm(ops[-1]) if ops else None
        return 2 if v is not None and -32 <= v <= 31 else 4
    if m == 'andi':
        return 2
    if m in ('xori', 'ori', 'slti', 'sltiu'):
        return 4
    if m in ('slli', 'srli', 'srai'):
        return 2
    if m in ('lw', 'sw'):
        if not ops:
            return 4
        mem = ops[-1]
        if '(' not in mem:
            return 4
        base = mem.split('(', 1)[1].split(')', 1)[0].strip()
        doff = imm(mem.split('(', 1)[0])
        rd = ops[0]
        if base in BASE_RVC and rd in BASE_RVC:
            return 2
        if base in BASE and doff is not None and 0 <= doff <= 12:
            return 2
        return 4
    if m in ('lb', 'lh', 'lbu', 'lhu', 'sb', 'sh'):
        return 2
    if m in ('beqz', 'bnez'):
        return 2
    if m in ('bne', 'blt', 'blez'):
        target = ops[-1] if ops else None
        dist = None
        if target in labels:
            dist = labels[target] - off
        regs_ok = len(ops) >= 2 and all(regno(r) is not None and
                                        8 <= regno(r) <= 15 for r in ops[:2])
        if m == 'blez':
            rng = -128 <= dist <= 126 if dist is not None else True
        else:
            rng = -16 <= dist <= 14 if dist is not None else True
        return 2 if regs_ok and rng else 4
    if m == 'beq':
        return 4
    if m == 'bge':
        return 2
    if m in ('bgeu', 'bltu'):
        return 6
    if m == 'seqz' or m == 'snez':
        return 4
    return 4


def parse(path):
    labels = {}
    instrs = []
    off = 0
    for raw in open(path):
        line = raw.split('#')[0].strip()
        if not line:
            continue
        if line.endswith(':'):
            labels[line[:-1]] = off
            continue
        if line.startswith('.'):
            continue
        parts = line.replace(',', ' ').split()
        if not parts:
            continue
        m = parts[0]
        ops = parts[1:]
        sz = actual_size(m, ops)
        instrs.append((off, m, ops))
        off += sz
    return labels, instrs, off


def model(path):
    labels, instrs, actual = parse(path)
    total = 0
    stack = 0
    branches = 0
    tramp = 0
    lui = 0
    gp = 0
    strs = 0
    i = 0
    while i < len(instrs):
        off, m, ops = instrs[i]
        if m == 'lui' and i + 1 < len(instrs):
            noff, nm, nops = instrs[i + 1]
            if nm in ('addi', 'lw', 'sw') and len(nops) >= 2:
                s = sym_of(nops[-1])
                k = classify(s)
                if k == 'gp':
                    total += 0
                    gp += 1
                    i += 2
                    if nm in ('lw', 'sw'):
                        total += 2
                    continue
                if k == 'str':
                    total += 6
                    strs += 1
                    i += 2
                    continue
                total += 16
                lui += 1
                i += 2
                if nm in ('lw', 'sw'):
                    total += 4
                continue
        if m == 'lui':
            total += 16
            lui += 1
        else:
            total += c_cost(m, ops, off, labels)
        if m in ('lw', 'sw') and any('(sp)' in o or '(x2)' in o for o in ops):
            stack += 1
        if m in ('bne', 'beq', 'blt', 'bge', 'blez', 'bgez', 'bnei'):
            branches += 1
            if c_cost(m, ops, off, labels) >= 4 and m in ('bne', 'blt', 'blez'):
                tramp += 1
        i += 1
    return actual, total, len(instrs), stack, branches, tramp, lui, gp, strs


if __name__ == '__main__':
    grand = [0, 0]
    for p in sys.argv[1:]:
        a, c, n, st, br, tr, lui, gp, strs = model(p)
        grand[0] += a
        grand[1] += c
        print('%s actual=%d c_model=%d instr=%d stack=%d branches=%d tramp=%d lui=%d gp=%d str=%d' %
              (p.split('/')[-1], a, c, n, st, br, tr, lui, gp, strs))
    print('TOTAL actual=%d c_model=%d' % (grand[0], grand[1]))
