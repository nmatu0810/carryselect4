#!/usr/bin/env bash
# Task 22: simulate the post-PnR netlist (pnr/final/nl) with SDF delays in Icarus.
#   scripts/run_postpnr_sim.sh <case> [corner]   corner default nom_tt_025C_1v80
# nom_tt writes postpnr.<case>.*; any other corner writes postpnr.<corner>.<case>.*.
# Icarus ignores SDF/model timing checks (setup/hold): this run checks function under real cell
# delays; setup/hold sign-off stays with OpenSTA (see docs/DEVIATIONS.md D7).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh
T=${1:-case1}
CORNER=${2:-nom_tt_025C_1v80}
SCALE=${SDF_SCALE:-1}
V="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
OUT=verif/out/pnr
mkdir -p "$OUT"
SDF_IN="pnr/final/sdf/$CORNER/carryselect4_top__$CORNER.sdf"
prep=$(python3 scripts/sdf_prep.py "$SDF_IN" "$OUT/$CORNER.sdf" --scale "$SCALE") || exit 1
echo "SDF $CORNER: $prep"
iverilog -g2012 -gspecify -DFLAT_NETLIST -DSETTLE_NS="${SETTLE_NS:-1.5}" -DSDF_FILE="\"$OUT/$CORNER.sdf\"" \
  -s tb_top -s sdf_load -o "$OUT/sim.vvp" \
  "$V/primitives.v" "$V/sky130_fd_sc_hd.v" "${NETLIST:-pnr/final/nl/carryselect4_top.nl.v}" \
  verif/tb/tb_top.sv verif/tb/tb_sdf.sv > "$OUT/compile.log" 2>&1 || { cat "$OUT/compile.log"; exit 1; }
vvp "$OUT/sim.vvp" +TEST="$T" 2>&1 | tee "$OUT/$T.$CORNER.log" | grep -vE 'SDF WARNING'
if [ "$CORNER" = nom_tt_025C_1v80 ]; then P="postpnr.$T"; else P="postpnr.$(echo "$CORNER" | cut -d_ -f1-2).$T"; fi
line=$(grep -E "^RESULT $T PASS checked=[0-9]+ errors=0\$" "$OUT/$T.$CORNER.log" || true)
if [ -n "$line" ]; then
  python3 scripts/metrics.py set "$P.status" PASS
  python3 scripts/metrics.py set "$P.checked" "$(sed -nE 's/.*checked=([0-9]+).*/\1/p' <<<"$line")"
  python3 scripts/metrics.py set "$P.errors" 0
  if [ "$SCALE" = 1 ]; then
    if [ "$CORNER" = nom_tt_025C_1v80 ]; then
      for k in cells iopaths interconnect_omitted interconnect_max_ns; do
        python3 scripts/metrics.py set "postpnr.sdf_$k" "$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['$k'])" "$prep")"
      done
      python3 scripts/metrics.py set postpnr.timingcheck_warnings "$(grep -c 'TIMINGCHECK not supported' "$OUT/$T.$CORNER.log")"
    else
      python3 scripts/metrics.py set "postpnr.$(echo "$CORNER" | cut -d_ -f1-2).sdf_interconnect_max_ns" \
        "$(python3 -c "import json,sys;print(json.loads(sys.argv[1])['interconnect_max_ns'])" "$prep")"
    fi
  fi
else
  [ "$SCALE" = 1 ] && python3 scripts/metrics.py set "$P.status" FAIL
  exit 1
fi
