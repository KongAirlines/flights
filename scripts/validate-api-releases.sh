#!/usr/bin/env bash
set -euo pipefail
ruby scripts/validate-api-releases.rb "${1:-}"
