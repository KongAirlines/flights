#!/usr/bin/env bash
set -euo pipefail

readonly TEAM="flight-data"
readonly OWNER="flights"
readonly SCOPE="flights"
readonly OBSOLETE_PATTERN='koct[l]|konnect-[o]rchestrator|ko-[p]atch'

if grep -q '^[[:space:]]*_deck:' konnect/prod.yaml; then
  echo "production Catalog manifests must not apply Gateway state" >&2
  exit 1
fi

if grep -q '^plugins:' gateway/prod/kong.yaml; then
  echo "service production state must not declare global plugins" >&2
  exit 1
fi

for stage in dev prod; do
  file="gateway/${stage}/kong.yaml"
  for tag in "env-${stage}" "team-${TEAM}" "owner-${OWNER}" "scope-${SCOPE}-${stage}"; do
    grep -Fq -- "- ${tag}" "${file}" || {
      echo "${file} is missing ownership tag ${tag}" >&2
      exit 1
    }
  done
done

if grep -Fq 'name: ace' gateway/prod/kong.yaml; then
  echo "public example APIs must not install ACE" >&2
  exit 1
fi

if grep -ERin "${OBSOLETE_PATTERN}" README.md .github gateway konnect scripts; then
  echo "obsolete Reference Platform tooling is not allowed" >&2
  exit 1
fi
