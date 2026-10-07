#!/usr/bin/env bash
# Copies the shared references/ into each skill folder that needs them, so every
# skill is self-contained when a tool installs it on its own (npx skills, Codex,
# Cursor, Copilot, ...). Edit references/ at the repo root, never the copies.
#
#   scripts/sync-references.sh          copy
#   scripts/sync-references.sh --check  fail if any copy is out of date (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

# skill -> references it reads
NEEDS=(
  "tracking-audit:standard.md crm-contract.md syntrix-contract.md discovery.md"
  "syntrix-setup:standard.md syntrix-contract.md discovery.md"
  "syntrix-guide:standard.md syntrix-contract.md"
  "syntrix-debug:standard.md syntrix-contract.md"
  "syntrix-reports:standard.md discovery.md"
  "stripe-metadata:standard.md discovery.md"
  "payment-standard:standard.md discovery.md"
  "crm-webhook:standard.md crm-contract.md discovery.md"
  "crm-app-data:standard.md crm-contract.md discovery.md"
  "crm-identity:standard.md crm-contract.md discovery.md"
)

stale=0
for entry in "${NEEDS[@]}"; do
  skill="${entry%%:*}"
  dest="skills/$skill/references"
  mkdir -p "$dest"
  for ref in ${entry#*:}; do
    if [[ "${1:-}" == "--check" ]]; then
      cmp -s "references/$ref" "$dest/$ref" || { echo "out of date: $dest/$ref"; stale=1; }
    else
      cp "references/$ref" "$dest/$ref"
    fi
  done
done

if [[ "${1:-}" == "--check" ]]; then
  [[ $stale == 0 ]] && echo "references in sync" || { echo "run scripts/sync-references.sh"; exit 1; }
else
  echo "references copied into skills/*/references/"
fi
