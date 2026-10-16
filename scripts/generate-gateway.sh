#!/usr/bin/env bash
set -euo pipefail

readonly SERVICE="flights"
readonly TEAM="flight-data"
readonly DECK_VERSION="1.65.2"

production_version="$(sed -nE 's/^    version:[[:space:]]*([^[:space:]#]+)[[:space:]]*$/\1/p' konnect/prod.yaml)"
if [[ -z "${production_version}" || "${production_version}" == *$'\n'* ]]; then
  echo "konnect/prod.yaml must declare exactly one API-level production version" >&2
  exit 1
fi
readonly PRODUCTION_SPEC="openapi/versions/${production_version}.yaml"

if [[ ! -f "${PRODUCTION_SPEC}" ]]; then
  echo "production specification ${PRODUCTION_SPEC} does not exist" >&2
  exit 1
fi

if [[ "$(deck version)" != *"v${DECK_VERSION}"* ]]; then
  echo "deck ${DECK_VERSION} is required" >&2
  exit 1
fi

for stage in dev prod; do
  spec="openapi.yaml"
  select_tag="scope-${SERVICE}-${stage}"
  if [[ "${stage}" == "prod" ]]; then
    spec="${PRODUCTION_SPEC}"
    select_tag="env-prod"
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT
  tags=("env-${stage}" "team-${TEAM}" "owner-${SERVICE}" "scope-${SERVICE}-${stage}")

  deck file openapi2kong \
    --analytics=false \
    --spec "${spec}" \
    --uuid-base "${SERVICE}-${stage}" \
    --select-tag "$(IFS=,; echo "${tags[*]}")" \
    --output-file "${tmp_dir}/generated.yaml"
  deck file patch \
    --analytics=false \
    --state "${tmp_dir}/generated.yaml" \
    --selector '$' \
    --value "_info:{\"select_tags\":[\"${select_tag}\"]}" \
    --output-file "${tmp_dir}/scoped.yaml"
  deck file patch \
    --analytics=false \
    --state "${tmp_dir}/scoped.yaml" \
    --selector '$..routes[?(@.paths[0]=="~/health$")]' \
    --value 'paths:["~/flights/health$"]' \
    --output-file "${tmp_dir}/routed.yaml"
  deck file add-tags \
    --analytics=false \
    --state "${tmp_dir}/routed.yaml" \
    --output-file "gateway/${stage}/kong.yaml" \
    "${tags[@]}"
  deck file validate "gateway/${stage}/kong.yaml"
  rm -rf "${tmp_dir}"
  trap - EXIT
done
