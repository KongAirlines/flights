#!/usr/bin/env bash
set -euo pipefail

readonly API_NAME="${1:?usage: $0 <catalog-api-name>}"

spec_version() {
  awk '
    /^info:[[:space:]]*$/ { in_info = 1; next }
    in_info && /^[^[:space:]]/ { exit }
    in_info && /^[[:space:]]+version:[[:space:]]*/ {
      sub(/^[[:space:]]+version:[[:space:]]*/, "")
      gsub(/"/, "")
      print
      exit
    }
  ' openapi.yaml
}

desired_version="$(spec_version)"
api_json="$(kongctl get api "${API_NAME}" --output json)"
api_id="$(jq -er '.id' <<< "${api_json}")"
current_version="$(jq -r '.version // ""' <<< "${api_json}")"
versions_json="$(kongctl api get "/v3/apis/${api_id}/versions" --output json)"

if ! jq -e --arg version "${desired_version}" \
  '.data[] | select(.version == $version)' <<< "${versions_json}" >/dev/null; then
  echo "API version ${desired_version} must be created by kongctl apply before selection" >&2
  exit 1
fi

if [[ "${current_version}" != "${desired_version}" ]]; then
  # Temporary workaround for https://github.com/Kong/kongctl/issues/2510.
  # Konnect requires explicit force authorization when ACE-governed operations
  # disappear while selecting a new current API version.
  kongctl api patch "/v3/apis/${api_id}?force=true" \
    "version=${desired_version}" >/dev/null
fi
