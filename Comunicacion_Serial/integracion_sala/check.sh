#!/usr/bin/env bash
set -eu -o pipefail
cd "$(dirname "$0")"
out=$(mktemp -d "${TMPDIR:-/tmp}/sala.XXXXXXXX")
trap 'rm -rf "$out"' EXIT
case ${1:-all} in sim|synth|all) ;; *) exit 2;; esac
if [[ ${1:-all} != synth ]]; then
  for half in 4 5 6; do
    printf 'Icarus: A period 10 ns, B period %d ns\n' "$((2*half))"
    iverilog -g2012 -Wall -s tb_sala -Ptb_sala.CB_HALF="$half" -o "$out/sim" tb_sala.sv sala_transport.v ../comunicacion_serial.v
    vvp "$out/sim"
  done
fi
if [[ ${1:-all} != sim ]]; then
  # Yosys parses initial/testbench constructs even with a different top.
  # Extract exactly the teammate's module, without its appended simulation.
  python3 - "$out/endpoint.v" <<'PY'
import re, sys
from pathlib import Path
src=Path('../comunicacion_serial.v').read_text()
mods=re.findall(r'^module\s+serial_endpoint\b.*?^endmodule\s*$',src,re.M|re.S)
assert len(mods)==1
Path(sys.argv[1]).write_text(mods[0]+'\n')
PY
  yosys -l "$out/yosys.log" -Q -q -p "read_verilog $out/endpoint.v sala_transport.v; hierarchy -check -top sala_transport; synth_gowin -top sala_transport -noiopads; check -assert; stat"
  python3 - "$out/yosys.log" <<'PY'
import sys
from pathlib import Path
lines=Path(sys.argv[1]).read_text().splitlines()
print('Gowin synthesis:',next(s.strip() for s in reversed(lines) if 'Found and reported' in s))
PY
fi
