#!/usr/bin/env bash
set -euo pipefail
# Run from repository root; extends paths resolve against this directory.
for stage in dev prod; do
  deck file lint --analytics=false --state "gateway/${stage}/kong.yaml" "lint/gateway-${stage}.yaml"
done
