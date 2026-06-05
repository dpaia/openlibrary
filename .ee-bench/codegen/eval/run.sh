#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${EE_BENCH_PROJECT_ROOT:-/app}"
EVAL_DIR="/ee-bench/eval"
SUBMISSION_DIR="/ee-bench/submission"

# --- Environment from Dockerfile (rendered from dockerfile_env_vars) ---
export LANG="en_US.UTF-8"
export LC_ALL="POSIX"
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
export UV_HTTP_TIMEOUT="60"

# --- Reset to base commit (only if EE_BENCH_RESET is set) ---
cd "$PROJECT_ROOT"
if [ -n "${EE_BENCH_RESET:-}" ]; then
  git reset --hard "630221ab686c64e75a2ce253c893c033e4814b2e" 2>/dev/null
  git checkout "630221ab686c64e75a2ce253c893c033e4814b2e" 2>/dev/null
  git clean -fd 2>/dev/null
fi

# --- Fetch commits referenced by before_repo_set_cmd ---

git fetch origin 7f7e53aa4cf74a4f8549a5bcd4810c527e2f6d7e 2>/dev/null || true

# --- before_repo_set_cmd (from HF metadata, may be empty) ---
git reset --hard 630221ab686c64e75a2ce253c893c033e4814b2e
git clean -fd 
git checkout 630221ab686c64e75a2ce253c893c033e4814b2e 
git checkout 7f7e53aa4cf74a4f8549a5bcd4810c527e2f6d7e -- openlibrary/catalog/add_book/tests/conftest.py openlibrary/tests/catalog/test_utils.py

# --- Apply evaluation data (test patch) ---
if [ -f "$EVAL_DIR/test_patch.diff" ]; then
  git apply -v "$EVAL_DIR/test_patch.diff" 2>/dev/null || true
fi

# --- Apply candidate submission ---
if [ -f "$SUBMISSION_DIR/patch.diff" ]; then
  git apply -v "$SUBMISSION_DIR/patch.diff" 2>/dev/null || true
fi

# --- Run tests via SWE-bench Pro run script ---

bash "$EVAL_DIR/scripts/run_script.sh" "openlibrary/tests/catalog/test_utils.py,openlibrary/catalog/add_book/tests/conftest.py" \
  > /tmp/stdout.log 2> /tmp/stderr.log || true


# --- Parse results ---
python3 "$EVAL_DIR/scripts/parser.py" /tmp/stdout.log /tmp/stderr.log /tmp/output.json

# --- Convert parser output to EE-bench JSON v2.0 format ---
python3 -c "
import json, sys, datetime
with open('/tmp/output.json') as f:
    data = json.load(f)
stdout = open('/tmp/stdout.log').read()
stderr = open('/tmp/stderr.log').read()

passed = [t for t in data.get('tests', []) if t['status'] == 'PASSED']
failed = [t for t in data.get('tests', []) if t['status'] in ('FAILED', 'ERROR')]
skipped = [t for t in data.get('tests', []) if t['status'] == 'SKIPPED']

summary = {
    'total': len(data.get('tests', [])),
    'passed': len(passed),
    'failed': len(failed),
    'errors': 0,
    'skipped': len(skipped),
}
passed_tests = [{'name': t['name']} for t in passed]
failed_tests = [{'name': t['name']} for t in failed]

result = {
    'schema_version': '2.0',
    'status': 'success',
    'timestamp': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'criteria': [
        {
            'criterion': 'patch_applied',
            'status': 'pass',
        },
        {
            'criterion': 'compilation',
            'status': 'pass',
        },
        {
            'criterion': 'tests',
            'status': 'pass' if not failed else 'fail',
            'summary': summary,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
        },
    ],
    'stdout': stdout,
    'stderr': stderr,
    # Deprecated v1.0 fields for backward compat
    'patch_applied': True,
    'compile_success': True,
    'summary': summary,
    'passed_tests': passed_tests,
    'failed_tests': failed_tests,
}
print(json.dumps(result))
"