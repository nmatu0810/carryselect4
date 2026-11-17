#!/usr/bin/env bash
# Task 21: gate-level simulation of the Yosys netlist (syn/out/carryselect4_top.syn.v) with Icarus.
#   scripts/run_glsim.sh <case>           (functional model, zero delay; same testbench as the RTL sim)
# Writes glsim.<case>.{status,checked,errors} to results/metrics.json.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh
T=${1:-case1}
NL=${NETLIST:-syn/out/carryselect4_top.syn.v}
V="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
OUT=verif/out/gl
mkdir -p "$OUT"
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY='#0' -s tb_top -o "$OUT/sim.vvp" \
  "$V/primitives.v" "$V/sky130_fd_sc_hd.v" "$NL" verif/tb/tb_top.sv || exit 1
set -o pipefail
vvp "$OUT/sim.vvp" +TEST="$T" | tee "$OUT/$T.log"
line=$(grep -E "^RESULT $T PASS checked=[0-9]+ errors=0\$" "$OUT/$T.log" || true)
if [ -n "$line" ]; then
  python3 scripts/metrics.py set "glsim.$T.status" PASS
  python3 scripts/metrics.py set "glsim.$T.checked" "$(sed -nE 's/.*checked=([0-9]+).*/\1/p' <<<"$line")"
  python3 scripts/metrics.py set "glsim.$T.errors" 0
else
  python3 scripts/metrics.py set "glsim.$T.status" FAIL
  exit 1
fi
