#!/usr/bin/env bash
set -euo pipefail

./scripts/validate-api-releases.sh "${RELEASE_BASE_SHA:-}"
kongctl lint -f openapi.yaml -r lint/openapi.yaml --fail-severity error
for stage in dev prod; do
  kongctl lint -f "konnect/${stage}.yaml" -r "lint/konnect-${stage}.yaml" --fail-severity error
done
bash scripts/lint-gateway.sh

# General repository text policy, outside manifest linting.
if grep -ERin 'koct[l]|konnect-[o]rchestrator|ko-[p]atch' README.md .github gateway konnect scripts; then
  echo "obsolete Reference Platform tooling is not allowed" >&2
  exit 1
fi
