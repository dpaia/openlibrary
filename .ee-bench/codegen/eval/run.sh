#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${EE_BENCH_PROJECT_ROOT:-/app}"
EVAL_DIR="/ee-bench/eval"
SUBMISSION_DIR="/ee-bench/submission"

# --- Environment from Dockerfile (rendered from dockerfile_env_vars) ---
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
export UV_HTTP_TIMEOUT="60"

# --- Reset to base commit (only if EE_BENCH_RESET is set) ---
cd "$PROJECT_ROOT"
if [ -n "${EE_BENCH_RESET:-}" ]; then
  git reset --hard "ab62fa4d63d15b7bc1b9a856ae9acd74df1f1f93" 2>/dev/null
  git checkout "ab62fa4d63d15b7bc1b9a856ae9acd74df1f1f93" 2>/dev/null
  git clean -fd 2>/dev/null
fi

# --- Fetch commits referenced by before_repo_set_cmd ---

git fetch origin 91efee627df01e32007abf2d6ebf73f9d9053076 2>/dev/null || true

# --- before_repo_set_cmd (from HF metadata, may be empty) ---
git reset --hard ab62fa4d63d15b7bc1b9a856ae9acd74df1f1f93
git clean -fd 
git checkout ab62fa4d63d15b7bc1b9a856ae9acd74df1f1f93 
git checkout 91efee627df01e32007abf2d6ebf73f9d9053076 -- openlibrary/utils/tests/test_dateutil.py

# --- Apply evaluation data (test patch) ---
if [ -f "$EVAL_DIR/test_patch.diff" ]; then
  git apply -v "$EVAL_DIR/test_patch.diff" 2>/dev/null || true
fi

# --- Apply candidate submission ---
if [ -f "$SUBMISSION_DIR/patch.diff" ]; then
  git apply -v "$SUBMISSION_DIR/patch.diff" 2>/dev/null || true
fi

# --- Run tests via SWE-bench Pro run script ---

bash "$EVAL_DIR/scripts/run_script.sh" "openlibrary/utils/tests/test_dateutil.py" \
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