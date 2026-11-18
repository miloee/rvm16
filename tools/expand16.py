#!/usr/bin/env python3
"""Minimal Expand16 prototype.

Reads a leaf-function RV32 assembly subset (clang -O2 output) and emits Q3
two-address code.  This is NOT the LLVM post-RA pass; it is a standalone
translator used to prove the C -> Q3 path while the pass is being written.

Supported: sll, mul, add, sub, slt, mv, li, ret.
Registers must be in x8-x15 (s0/s1/a0-a5); the Q3/RVC forms cannot encode
x16-x31 for add/sub/mv.
"""
import re
import sys

ALLOWED = {"a0", "a1", "a2", "a3", "a4", "a5", "s0", "s1"}
TEMP_ORDER = ["a4", "a5", "a3", "a2", "a1", "a0", "s0", "s1"]


def check(reg):
    if reg not in ALLOWED:
        raise SystemExit("register %s is outside x8-x15" % reg)


def emit_mv(dst, src):
    check(dst); check(src)
    return ["  c.mv %s, %s" % (dst, src)]


def expand(op, args):
    if op == "ret":
        return ["  c.jr ra"]
    if op == "mv":
        rd, rs = [x.strip() for x in args.split(",")]
        return emit_mv(rd, rs)
    if op == "li":
        rd, imm = [x.strip() for x in args.split(",")]
        check(rd)
        return ["  c.li %s, %s" % (rd, imm)]
    if op not in ("sll", "mul", "add", "sub", "slt"):
        raise SystemExit("unsupported op: " + op)
    rd, rs1, rs2 = [x.strip() for x in args.split(",")]
    check(rd); check(rs1); check(rs2)
    out = []
    if op in ("sll", "mul"):
        if rd != rs1:
            out += emit_mv(rd, rs1)
        out.append("  c.%s %s, %s" % (op, rd, rs2))
    elif op == "add":
        if rd == rs1:
            out.append("  c.add %s, %s" % (rd, rs2))
        elif rd == rs2:
            out.append("  c.add %s, %s" % (rd, rs1))
        else:
            out += emit_mv(rd, rs1)
            out.append("  c.add %s, %s" % (rd, rs2))
    elif op == "slt":
        if rd != rs1:
            out += emit_mv(rd, rs1)
        out.append("  c.slt %s, %s" % (rd, rs2))
    elif op == "sub":
        if rd == rs1:
            out.append("  c.sub %s, %s" % (rd, rs2))
        else:
            used = {rd, rs1, rs2}
            temp = next((r for r in TEMP_ORDER if r not in used), None)
            if temp is None:
                raise SystemExit("no free temp for sub")
            out += emit_mv(temp, rs2)
            out += emit_mv(rd, rs1)
            out.append("  c.sub %s, %s" % (rd, temp))
    return out


def main():
    src = sys.stdin.read().splitlines()
    out = [".text", ".p2align 1", ".Lf:"]
    for line in src:
        line = line.split("#")[0].strip()
        if not line or line.startswith("."):
            continue
        if line.endswith(":"):
            continue
        if line == "ret":
            out.append("  c.jr ra")
            continue
        m = re.match(r"([a-z.]+)\s+(.*)", line)
        if not m:
            continue
        op, args = m.group(1), m.group(2)
        if op.startswith("c."):
            out.append("  " + line)
            continue
        out += expand(op, args)
    out += [".size .Lf, .-.Lf"]
    print("\n".join(out))


if __name__ == "__main__":
    main()
