#!/usr/bin/env python3
"""Minimal RV32I assembler.

Writes one 32-bit hex word per line, ready for $readmemh.
Supports all RV32I instructions, labels, '#' comments and common pseudo-ops
(nop, li, mv, not, neg, seqz, snez, j, jr, ret, call, beqz, bnez, bltz,
bgez, blez, bgtz, bgt, ble, bgtu, bleu).

Usage: asm.py input.S -o output.hex [-l]   (-l prints a listing)
"""
import argparse
import re
import sys

ABI = ("zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 "
       "s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6").split()
REGS = {f"x{i}": i for i in range(32)}
REGS.update({name: i for i, name in enumerate(ABI)})
REGS["fp"] = 8

R_OPS = {"add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
         "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
         "or": (0x00, 6), "and": (0x00, 7)}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SHIFT_I = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}

MEM_RE = re.compile(r"^(.*)\(\s*(\w+)\s*\)$")


class AsmError(Exception):
    pass


def to_s32(v):
    v &= 0xFFFFFFFF
    return v - (1 << 32) if v & 0x80000000 else v


def sext12(v):
    v &= 0xFFF
    return v - 0x1000 if v & 0x800 else v


def num(s):
    try:
        return int(s.strip(), 0)
    except ValueError:
        raise AsmError(f"bad number '{s}'")


def reg(s):
    s = s.strip().lower()
    if s not in REGS:
        raise AsmError(f"unknown register '{s}'")
    return REGS[s]


def mem_op(s):
    m = MEM_RE.match(s.strip())
    if not m:
        raise AsmError(f"expected offset(reg), got '{s}'")
    off = m.group(1).strip() or "0"
    return num(off), reg(m.group(2))


def check_range(v, lo, hi, what):
    if not lo <= v <= hi:
        raise AsmError(f"{what} {v} out of range [{lo}, {hi}]")


def nargs(ops, n, mn):
    if len(ops) != n:
        raise AsmError(f"'{mn}' expects {n} operands, got {len(ops)}")


# ---------------------------------------------------------------- formats
def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    check_range(imm, -2048, 2047, "immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    check_range(imm, -2048, 2047, "store offset")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | \
           ((imm & 0x1F) << 7) | op


def enc_b(off, rs2, rs1, f3, op):
    check_range(off, -4096, 4094, "branch offset")
    if off & 1:
        raise AsmError("branch offset must be even")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (f3 << 12) | (((o >> 1) & 0xF) << 8) | \
           (((o >> 11) & 1) << 7) | op


def enc_u(imm, rd, op):
    check_range(imm, -0x80000, 0xFFFFF, "upper immediate")
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(off, rd, op):
    check_range(off, -(1 << 20), (1 << 20) - 2, "jump offset")
    if off & 1:
        raise AsmError("jump offset must be even")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | \
           (((o >> 11) & 1) << 20) | (((o >> 12) & 0xFF) << 12) | (rd << 7) | op


# ---------------------------------------------------------------- pseudos
def expand(mn, ops):
    """Rewrite pseudo-instructions into real ones. Sizes are fixed here so
    labels can be resolved in a single pre-pass."""
    if mn == "nop":
        return [("addi", ["x0", "x0", "0"])]
    if mn == "li":
        nargs(ops, 2, mn)
        rd, v = ops[0], to_s32(num(ops[1]))
        if -2048 <= v <= 2047:
            return [("addi", [rd, "x0", str(v)])]
        lo = sext12(v)
        hi = ((v - lo) >> 12) & 0xFFFFF
        out = [("lui", [rd, str(hi)])]
        if lo:
            out.append(("addi", [rd, rd, str(lo)]))
        return out
    if mn == "mv":
        return [("addi", [ops[0], ops[1], "0"])]
    if mn == "not":
        return [("xori", [ops[0], ops[1], "-1"])]
    if mn == "neg":
        return [("sub", [ops[0], "x0", ops[1]])]
    if mn == "seqz":
        return [("sltiu", [ops[0], ops[1], "1"])]
    if mn == "snez":
        return [("sltu", [ops[0], "x0", ops[1]])]
    if mn == "j":
        return [("jal", ["x0", ops[0]])]
    if mn == "jal" and len(ops) == 1:
        return [("jal", ["ra", ops[0]])]
    if mn == "call":
        return [("jal", ["ra", ops[0]])]
    if mn == "jr":
        return [("jalr", ["x0", ops[0], "0"])]
    if mn == "jalr" and len(ops) == 1:
        return [("jalr", ["ra", ops[0], "0"])]
    if mn == "ret":
        return [("jalr", ["x0", "ra", "0"])]
    zero_br = {"beqz": ("beq", 0), "bnez": ("bne", 0), "bltz": ("blt", 0),
               "bgez": ("bge", 0), "blez": ("bge", 1), "bgtz": ("blt", 1)}
    if mn in zero_br:
        real, swap = zero_br[mn]
        a, b = (ops[0], "x0") if not swap else ("x0", ops[0])
        return [(real, [a, b, ops[1]])]
    swap_br = {"bgt": "blt", "ble": "bge", "bgtu": "bltu", "bleu": "bgeu"}
    if mn in swap_br:
        return [(swap_br[mn], [ops[1], ops[0], ops[2]])]
    return [(mn, ops)]


# ---------------------------------------------------------------- encoder
def target(tok, labels, pc):
    tok = tok.strip()
    if tok in labels:
        return labels[tok] - pc
    return num(tok)


def encode(mn, ops, pc, labels):
    if mn in R_OPS:
        nargs(ops, 3, mn)
        f7, f3 = R_OPS[mn]
        return enc_r(f7, reg(ops[2]), reg(ops[1]), f3, reg(ops[0]), 0x33)
    if mn in I_ALU:
        nargs(ops, 3, mn)
        return enc_i(num(ops[2]), reg(ops[1]), I_ALU[mn], reg(ops[0]), 0x13)
    if mn in SHIFT_I:
        nargs(ops, 3, mn)
        f7, f3 = SHIFT_I[mn]
        sh = num(ops[2])
        check_range(sh, 0, 31, "shift amount")
        return enc_r(f7, sh, reg(ops[1]), f3, reg(ops[0]), 0x13)
    if mn in LOADS:
        nargs(ops, 2, mn)
        off, rs1 = mem_op(ops[1])
        return enc_i(off, rs1, LOADS[mn], reg(ops[0]), 0x03)
    if mn in STORES:
        nargs(ops, 2, mn)
        off, rs1 = mem_op(ops[1])
        return enc_s(off, reg(ops[0]), rs1, STORES[mn], 0x23)
    if mn in BRANCHES:
        nargs(ops, 3, mn)
        return enc_b(target(ops[2], labels, pc), reg(ops[1]), reg(ops[0]),
                     BRANCHES[mn], 0x63)
    if mn == "jal":
        nargs(ops, 2, mn)
        return enc_j(target(ops[1], labels, pc), reg(ops[0]), 0x6F)
    if mn == "jalr":
        if len(ops) == 2:                       # jalr rd, off(rs1)
            off, rs1 = mem_op(ops[1])
        else:                                   # jalr rd, rs1, off
            nargs(ops, 3, mn)
            rs1, off = reg(ops[1]), num(ops[2])
        return enc_i(off, rs1, 0, reg(ops[0]), 0x67)
    if mn == "lui":
        nargs(ops, 2, mn)
        return enc_u(num(ops[1]), reg(ops[0]), 0x37)
    if mn == "auipc":
        nargs(ops, 2, mn)
        return enc_u(num(ops[1]), reg(ops[0]), 0x17)
    if mn == "fence":
        return 0x0FF0000F
    if mn == "ecall":
        return 0x00000073
    if mn == "ebreak":
        return 0x00100073
    raise AsmError(f"unknown instruction '{mn}'")


def assemble(text):
    labels, insns, pc = {}, [], 0
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        try:
            while ":" in line:
                lab, line = line.split(":", 1)
                lab, line = lab.strip(), line.strip()
                if not re.match(r"^[A-Za-z_.][\w.]*$", lab):
                    raise AsmError(f"bad label '{lab}'")
                if lab in labels:
                    raise AsmError(f"duplicate label '{lab}'")
                labels[lab] = pc
            if not line:
                continue
            parts = line.split(None, 1)
            mn = parts[0].lower()
            ops = [o.strip() for o in parts[1].split(",")] if len(parts) > 1 else []
            for real in expand(mn, ops):
                insns.append((lineno, raw.strip(), pc, real))
                pc += 4
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}")

    words = []
    for lineno, src, pc, (mn, ops) in insns:
        try:
            words.append((pc, encode(mn, ops, pc, labels), src))
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}  ({src})")
    return words


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("input")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("-l", "--listing", action="store_true")
    args = ap.parse_args()

    with open(args.input) as f:
        try:
            words = assemble(f.read())
        except AsmError as e:
            sys.exit(f"{args.input}: {e}")

    with open(args.output, "w") as f:
        for _, w, _ in words:
            f.write(f"{w:08x}\n")
    if args.listing:
        for pc, w, src in words:
            print(f"{pc:08x}: {w:08x}    {src}")


if __name__ == "__main__":
    main()
