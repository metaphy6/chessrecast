#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="${ROOT_DIR}/frontend"
REPORT_PATH="${FRIENDLY_FIRE_BATCH_REPORT_PATH:-/tmp/friendly_fire_audit_batch_chunked_report.txt}"
TMP_DIR="${FRIENDLY_FIRE_BATCH_TMP_DIR:-/tmp/friendly_fire_batch_chunks}"
MAX_PARALLEL="${FRIENDLY_FIRE_BATCH_MAX_PARALLEL:-2}"

mkdir -p "${TMP_DIR}"

if ! [[ "${MAX_PARALLEL}" =~ ^[0-9]+$ ]] || [[ "${MAX_PARALLEL}" -lt 1 ]]; then
    echo "FRIENDLY_FIRE_BATCH_MAX_PARALLEL must be a positive integer" >&2
    exit 1
fi

export CHESSRECAST_NATIVE_ENGINE_LIB="${CHESSRECAST_NATIVE_ENGINE_LIB:-${FRONTEND_DIR}/build/native/linux/libchess_engine.so}"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-${FRONTEND_DIR}/build/native/linux:${FRONTEND_DIR}}"

chunks=(
    "e2e4,e7e5;e2e4,d7d5;e2e4,f7f5;e2e4,c7c5;e2e4,b7b5"
    "d2d4,e7e5;d2d4,d7d5;d2d4,f7f5;d2d4,c7c5;d2d4,b7b5"
    "f2f4,e7e5;f2f4,d7d5;f2f4,f7f5;f2f4,c7c5;f2f4,b7b5"
    "c2c4,e7e5;c2c4,d7d5;c2c4,f7f5;c2c4,c7c5;c2c4,b7b5"
    "b2b4,e7e5;b2b4,d7d5;b2b4,f7f5;b2b4,c7c5;b2b4,b7b5"
    "g2g4,e7e5;g2g4,d7d5;g2g4,f7f5;g2g4,c7c5;g2g4,b7b5"
    "e2e3,e7e5;e2e3,d7d5;e2e3,f7f5;e2e3,c7c5;e2e3,b7b5"
    "d2d3,e7e5;d2d3,d7d5;d2d3,f7f5;d2d3,c7c5;d2d3,b7b5"
    "f2f3,e7e5;f2f3,d7d5;f2f3,f7f5;f2f3,c7c5;f2f3,b7b5"
    "c2c3,e7e5;c2c3,d7d5;c2c3,f7f5;c2c3,c7c5;c2c3,b7b5"
)

chunk_count="${#chunks[@]}"
pids=()
active_jobs=0
failed=0

cleanup() {
    for pid in "${pids[@]:-}"; do
        kill "${pid}" 2>/dev/null || true
    done
}

trap cleanup INT TERM

for index in "${!chunks[@]}"; do
    chunk_id="$((index + 1))"
    report_file="${TMP_DIR}/ff_chunk${chunk_id}_report.txt"
    log_file="${TMP_DIR}/ff_chunk${chunk_id}.log"
    rm -f "${report_file}" "${log_file}"

    printf 'Starting Friendly Fire chunk %s/%s\n' "${chunk_id}" "${chunk_count}"
    (
        cd "${FRONTEND_DIR}"
        export FRIENDLY_FIRE_BATCH_OPENINGS="${chunks[index]}"
        export FRIENDLY_FIRE_BATCH_REPORT_PATH="${report_file}"
        flutter test test/manual_friendly_fire_audit_batch_test.dart --run-skipped -r compact >"${log_file}" 2>&1
    ) &
    pids+=("$!")
    active_jobs="$((active_jobs + 1))"

    if [[ "${active_jobs}" -ge "${MAX_PARALLEL}" ]]; then
        if ! wait -n; then
            failed=1
            break
        fi
        active_jobs="$((active_jobs - 1))"
    fi
done

for pid in "${pids[@]}"; do
    if ! wait "${pid}"; then
        failed=1
    fi
done

trap - INT TERM

if [[ "${failed}" -ne 0 ]]; then
    exit 1
fi

python3 - "${REPORT_PATH}" "${TMP_DIR}" <<'PY'
from pathlib import Path
import re
import sys

report_path = Path(sys.argv[1])
tmp_dir = Path(sys.argv[2])
chunk_files = [
    (tmp_dir / 'ff_chunk1_report.txt', 0),
    (tmp_dir / 'ff_chunk2_report.txt', 5),
    (tmp_dir / 'ff_chunk3_report.txt', 10),
    (tmp_dir / 'ff_chunk4_report.txt', 15),
    (tmp_dir / 'ff_chunk5_report.txt', 20),
    (tmp_dir / 'ff_chunk6_report.txt', 25),
    (tmp_dir / 'ff_chunk7_report.txt', 30),
    (tmp_dir / 'ff_chunk8_report.txt', 35),
    (tmp_dir / 'ff_chunk9_report.txt', 40),
    (tmp_dir / 'ff_chunk10_report.txt', 45),
]

game_pat = re.compile(r'^GAME (\d+) (.+)$')
status_pat = re.compile(r'^status=(.+?) worst=([+-]?\d+\.\d+) played=(.+) ref=(.+)$')

records = []
for path, offset in chunk_files:
    if not path.exists():
        raise SystemExit(f'missing chunk report: {path}')
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        match = game_pat.match(lines[i])
        if not match:
            i += 1
            continue

        status_match = status_pat.match(lines[i + 1])
        if status_match is None:
            raise SystemExit(f'failed to parse status line in {path}: {lines[i + 1]!r}')

        records.append(
            {
                'game': offset + int(match.group(1)),
                'opening': match.group(2),
                'status': status_match.group(1),
                'delta': float(status_match.group(2)),
                'played': status_match.group(3),
                'ref': status_match.group(4),
                'fen': lines[i + 2].removeprefix('FEN: '),
                'replay': lines[i + 3].removeprefix('Replay: '),
            }
        )
        i += 4

records.sort(key=lambda item: item['game'])
if len(records) != 50:
    raise SystemExit(f'expected 50 openings, found {len(records)}')

avg = sum(item['delta'] for item in records) / len(records)
max_delta = max(item['delta'] for item in records)
over_two = sum(item['delta'] >= 2.0 for item in records)
over_three = sum(item['delta'] >= 3.0 for item in records)

lines = [
    'Friendly Fire batch audit: 50 openings, baseline d4/120ms s4 vs reference d6/500ms s4, max plies 24'
]

for item in records:
    lines.append(f"GAME {item['game']} {item['opening']}")
    lines.append(
        f"status={item['status']} worst={item['delta']:+.2f} played={item['played']} ref={item['ref']}"
    )
    lines.append(f"FEN: {item['fen']}")
    lines.append(f"Replay: {item['replay']}")

lines.append('')
lines.append(
    f'Aggregate: avg worst miss {avg:.2f} max {max_delta:.2f} >=2.00 {over_two}/{len(records)} >=3.00 {over_three}/{len(records)}'
)
lines.append('')
lines.append('Worst openings:')

for index, item in enumerate(sorted(records, key=lambda item: item['delta'], reverse=True)[:10], 1):
    lines.append(
        f"{index}. GAME {item['game']} {item['opening']} delta={item['delta']:+.2f} played={item['played']} ref={item['ref']}"
    )
    lines.append(f"   FEN: {item['fen']}")
    lines.append(f"   Replay: {item['replay']}")

report_path.write_text('\n'.join(lines) + '\n')
print(report_path.read_text(), end='')
PY