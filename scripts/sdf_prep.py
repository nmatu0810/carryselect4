#!/usr/bin/env python3
"""Prepare an OpenSTA SDF for Icarus Verilog's $sdf_annotate (Task 22).

Icarus cannot annotate cell-to-cell INTERCONNECT entries and rejects the VOLTAGE/PROCESS/TEMPERATURE
header lines, so both are dropped; every cell IOPATH delay is kept. Prints a JSON summary
(interconnect entries and their largest delay) so the omission is quantified, not hidden.
  sdf_prep.py <in.sdf> <out.sdf> [--scale K]    --scale multiplies all IOPATH delays (negative test)
"""
import json
import re
import sys


def split_cells(body):
    cells, depth, start = [], 0, None
    for k, c in enumerate(body):
        if c == "(":
            if depth == 0:
                start = k
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                cells.append(body[start:k + 1])
    return cells


def main():
    src, dst = sys.argv[1], sys.argv[2]
    scale = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 1.0
    t = open(src).read()
    i = t.index("(CELL")
    head, body = t[:i], t[i:]
    head = re.sub(r"\s*\((VOLTAGE|PROCESS|TEMPERATURE) [^\n]*", "", head)
    design = re.search(r'\(DESIGN "([^"]+)"', head).group(1)
    ic_n, ic_max, kept = 0, 0.0, []
    for c in split_cells(body):
        if f'CELLTYPE "{design}"' in c:
            for ln in re.findall(r"\(INTERCONNECT [^\n]*", c):
                ic_n += 1
                for v in re.findall(r"\(([\d.]+):[\d.]+:[\d.]+\)", ln):
                    ic_max = max(ic_max, float(v))
            continue
        kept.append(c)
    out = head + "\n".join(kept) + ")\n"
    if scale != 1.0:
        def sc(m):
            return "(" + ":".join(f"{float(x) * scale:.3f}" for x in m.group(1).split(":")) + ")"
        out = re.sub(r"(?<=\(IOPATH )([^\n]*)", lambda m: re.sub(r"\(([\d.]+:[\d.]+:[\d.]+)\)", sc, m.group(1)), out)
    open(dst, "w").write(out)
    print(json.dumps({
        "cells": len(kept),
        "iopaths": len(re.findall(r"\(IOPATH ", out)),
        "interconnect_omitted": ic_n,
        "interconnect_max_ns": ic_max,
    }))


if __name__ == "__main__":
    main()
