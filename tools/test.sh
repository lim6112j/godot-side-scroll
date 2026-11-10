#!/usr/bin/env bash
# Headless test harness entry point.
#
# Running a scene directly (`--headless --path . res://...`) skips Godot's
# project scan, so the global class cache (and thus `class_name TestHelper`)
# is never registered on a clean checkout. The cache is also stale whenever a
# new `class_name` script is added after the last import — an existence check
# cannot detect that — so import unconditionally before testing.
#
# Aborting suites are failures (태스크 14 리뷰). A suite that emits checks and
# then hits a runtime error used to be reported as `ALL N CHECKS PASSED` with
# exit=0, because GDScript silently terminates a coroutine that errors and the
# awaiting runner resumes as if nothing happened. The runner cannot see that
# from inside GDScript (see the header comment in tests/test_runner.gd), so
# this wrapper treats Godot's own `SCRIPT ERROR` report as a failure. Godot
# prints the offending file and line, which names the aborting suite.
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> importing project"
"$GODOT" --headless --path "$ROOT" --import
import_status=$?
if [ "$import_status" -ne 0 ]; then
    echo "ERROR: project import failed (exit $import_status); not running tests against a stale cache" >&2
    exit "$import_status"
fi

test_out="$("$GODOT" --headless --path "$ROOT" res://tests/test_runner.tscn 2>&1)"
test_status=$?
printf '%s\n' "$test_out"

if printf '%s' "$test_out" | grep -q "SCRIPT ERROR"; then
    echo "" >&2
    echo "ERROR: 스크립트 런타임 오류가 발생했다 — 어떤 스위트가 실행을 마치지" >&2
    echo "      못하고 중단됐다. 위 SCRIPT ERROR 의 파일명이 그 스위트이며," >&2
    echo "      그 뒤의 검사들은 전부 빠져 나간 것이다 (태스크 14 리뷰)." >&2
    exit 1
fi

exit "$test_status"
