#!/usr/bin/env bash
# Compat suites against a running Stalwart + Authfly + Console (an `authfly deploy` dir, or the dev stack):
#   tools/e2e-compat.sh <deploy dir>     # secrets read as root from <dir>/.authfly/secrets (never printed)
#   tools/e2e-compat.sh                  # dev stack (docker compose up -d --build): dev defaults from e2e/lib.ts
# 1. e2e/console.test.ts: the Console against live Stalwart (schema-driven forms, users, audit).
# 2. tools/stalwart-audit.py: re-probes the whole management surface; a diff in docs/api-capture/schema.json means
#    the Stalwart API changed under us (the run prints `git diff --stat`).
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
if [ -n "${1:-}" ]; then
  dir=$(cd "$1" && pwd); y=$dir/authfly.yaml
  sec() { sudo -n cat "$dir/.authfly/secrets/$1"; }
  export AUTHFLY_URL=http://localhost:4000 STALWART_URL=http://localhost:8080 CONSOLE_URL=http://localhost:4500
  export AUTHFLY_DOMAIN=$(sed -n 's/^domain: *//p' "$y" | tr -d '"')
  export STALWART_ADMIN="admin:$(sec stalwart_admin_password)" CONSOLE_ADMIN="console:$(sec console_password)"
fi
cd "$root"
fail=0
echo "== console"; bun e2e/console.test.ts 2>&1 | tail -${E2E_TAIL:-40} || fail=1
echo "== stalwart-audit"; python3 tools/stalwart-audit.py 2>&1 | tail -5 || fail=1
if git diff --quiet -- docs/api-capture/schema.json; then echo "stalwart API schema: unchanged (compatible)"; else echo "stalwart API schema CHANGED:"; git diff --stat -- docs/api-capture/schema.json; fail=1; fi
# probe.json holds live sample data (ids, test accounts): keep the committed one unless AUDIT_KEEP=1
[ -n "${AUDIT_KEEP:-}" ] || git checkout -q -- docs/api-capture/probe.json docs/stalwart-api.md
exit $fail
