#!/usr/bin/env python3
"""Minimal Expand16 prototype (leaf functions + simple loops).

Reads the RV32 assembly emitted by clang -O2 for a small integer function and
emits Q3/RVC two-address code.  This is NOT the LLVM post-RA pass.

Supported: li, mv, add, addi, sub, sll, slli, mul, slt, lw, sw,
           blez, bne, beq, blt, bge, j, ret, labels.
Registers must be in x8-x15 (s0/s1/a0-a5); add/sub/mv cannot encode x16-x31.
"""
import sys

ALLOWED = {"a0", "a1", "a2", "a3", "a4", "a5", "s0", "s1"}
LS_ALLOWED = ALLOWED | {"ra"}
BASES = {"s0", "s1", "sp", "gp"}
TEMP_ORDER = ["a4", "a5", "a3", "a2", "a1", "a0", "s0", "s1"]


def check(reg):
    if reg not in ALLOWED:
        raise SystemExit("register %s is outside x8-x15" % reg)


def check_mv(reg):
    if reg in ("x0", "zero") or (reg not in ALLOWED and reg not in ("sp", "ra")):
        raise SystemExit("mv register %s cannot be encoded" % reg)


def check_ls(reg):
    if reg not in LS_ALLOWED:
        raise SystemExit("register %s is outside x0-x15" % reg)


def pick_temp(used):
    for r in TEMP_ORDER:
        if r not in used:
            return r
    raise SystemExit("no free temp")


def pick_base(used):
    for r in ("s0", "s1"):
        if r not in used:
            return r
    raise SystemExit("no free base")


def mv(dst, src):
    check_mv(dst); check_mv(src)
    return ["  c.mv %s, %s" % (dst, src)]


def li32(reg, value):
    """Build a 32-bit constant with c.li/c.slli/c.addi (5-bit chunks)."""
    value &= 0xFFFFFFFF
    signed = value if value < 0x80000000 else value - 0x100000000
    if -32 <= signed <= 31:
        return ["  c.li %s, %d" % (reg, signed)]
    out = ["  c.li %s, %d" % (reg, value >> 30)]
    for shift in (25, 20, 15, 10, 5, 0):
        out.append("  c.slli %s, 5" % reg)
        chunk = (value >> shift) & 31
        if chunk:
            out.append("  c.addi %s, %d" % (reg, chunk))
    return out


def label(name):
    if name.startswith(".L") or name[:1].isdigit():
        return name
    return ".L" + name


def expand(op, rest):
    if op == "ret":
        return ["  c.jr ra"]
    if op == "nop":
        return ["  c.nop"]
    if op == "j":
        return ["  c.j %s" % label(rest.strip())]

    a = [x.strip() for x in rest.split(",")]

    if op == "li":
        if a[0] not in ALLOWED and a[0] not in ("sp", "ra"):
            raise SystemExit("register %s cannot hold li" % a[0])
        return li32(a[0], int(a[1], 0))
        return ["  c.li %s, %s" % (a[0], a[1])]
    if op == "mv":
        return mv(a[0], a[1])
    if op in ("call", "jal"):
        target = rest.split(",")[-1].strip()
        return ["  c.jal %s" % label(target)]

    if op in ("lw", "sw"):
        reg = a[0]
        mem = a[1]
        off, base = mem[:-1].split("(")
        off = int(off)
        check_ls(reg)
        if off % 4 != 0 or off // 4 > 3:
            raise SystemExit("offset %d out of range for %s" % (off, op))
        field = off // 4
        used = {reg, base}
        if base in BASES:
            breg, pre = base, []
        else:
            breg = pick_base(used)
            pre = mv(breg, base)
        return pre + ["  c.%s %s, %d(%s)" % (op, reg, field, breg)]

    if op == "blez":
        rs, target = a[0], a[1]
        check(rs)
        t = pick_temp({rs})
        return ["  c.li %s, 0" % t, "  c.slt %s, %s" % (t, rs),
                "  c.beqz %s, %s" % (t, label(target))]

    if op in ("bne", "beq"):
        rs1, rs2, target = a[0], a[1], a[2]
        check(rs1); check(rs2)
        t = pick_temp({rs1, rs2})
        out = mv(t, rs1) + ["  c.xor %s, %s" % (t, rs2)]
        out.append("  c.%s %s, %s" % ("bnez" if op == "bne" else "beqz",
                                      t, label(target)))
        return out

    if op in ("blt", "bge"):
        rs1, rs2, target = a[0], a[1], a[2]
        check(rs1); check(rs2)
        t = pick_temp({rs1, rs2})
        out = mv(t, rs1) + ["  c.slt %s, %s" % (t, rs2)]
        out.append("  c.%s %s, %s" % ("bnez" if op == "blt" else "beqz",
                                      t, label(target)))
        return out

    if op == "addi":
        rd, rs1, imm = a[0], a[1], a[2]
        if rd == rs1 and rd in ("sp", "ra"):
            return ["  c.addi %s, %s" % (rd, imm)]
        check(rd); check(rs1)
        out = [] if rd == rs1 else mv(rd, rs1)
        return out + ["  c.addi %s, %s" % (rd, imm)]

    if op == "slli":
        rd, rs1, imm = a[0], a[1], a[2]
        check(rd); check(rs1)
        out = [] if rd == rs1 else mv(rd, rs1)
        return out + ["  c.slli %s, %s" % (rd, imm)]

    if op not in ("sll", "mul", "add", "sub", "slt"):
        raise SystemExit("unsupported op: " + op)
    rd, rs1, rs2 = a[0], a[1], a[2]
    check(rd); check(rs1); check(rs2)
    out = []
    if op in ("sll", "mul"):
        if rd == rs1:
            out.append("  c.%s %s, %s" % (op, rd, rs2))
        elif rd == rs2:
            if op == "mul":
                out.append("  c.mul %s, %s" % (rd, rs1))
            else:
                t = pick_temp({rd, rs1, rs2})
                out += mv(t, rs2) + mv(rd, rs1)
                out.append("  c.sll %s, %s" % (rd, t))
        else:
            out += mv(rd, rs1)
            out.append("  c.%s %s, %s" % (op, rd, rs2))
    elif op == "add":
        if rd == rs1:
            out.append("  c.add %s, %s" % (rd, rs2))
        elif rd == rs2:
            out.append("  c.add %s, %s" % (rd, rs1))
        else:
            out += mv(rd, rs1)
            out.append("  c.add %s, %s" % (rd, rs2))
    elif op == "slt":
        if rd == rs1:
            out.append("  c.slt %s, %s" % (rd, rs2))
        elif rd == rs2:
            t = pick_temp({rd, rs1, rs2})
            out += mv(t, rs2) + mv(rd, rs1)
            out.append("  c.slt %s, %s" % (rd, t))
        else:
            out += mv(rd, rs1)
            out.append("  c.slt %s, %s" % (rd, rs2))
    elif op == "sub":
        if rd == rs1:
            out.append("  c.sub %s, %s" % (rd, rs2))
        else:
            t = pick_temp({rd, rs1, rs2})
            out += mv(t, rs2) + mv(rd, rs1)
            out.append("  c.sub %s, %s" % (rd, t))
    return out


def main():
    out = [".text", ".p2align 1"]
    for line in sys.stdin:
        line = line.split("#")[0].strip()
        if not line:
            continue
        if line.endswith(":"):
            out.append(label(line[:-1]) + ":")
            continue
        if line.startswith("."):
            continue
        parts = line.split(None, 1)
        op = parts[0]
        rest = parts[1] if len(parts) > 1 else ""
        if op.startswith("c."):
            out.append("  " + line)
            continue
        out += expand(op, rest)
    print("\n".join(out))


if __name__ == "__main__":
    main()
