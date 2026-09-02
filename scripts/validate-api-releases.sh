#!/usr/bin/env bash
set -euo pipefail

readonly BASE_SHA="${1:-}"
readonly STABLE_VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'
readonly BETA_VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$'
readonly PRODUCTION_SPEC_PATTERN='^\.\./openapi/versions/[0-9]+\.[0-9]+\.[0-9]+\.yaml$'

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
  ' "$1"
}

development_version="$(spec_version openapi.yaml)"
if [[ ! "${development_version}" =~ ${BETA_VERSION_PATTERN} ]]; then
  echo "openapi.yaml version must be a beta such as 0.2.0-beta.1" >&2
  exit 1
fi

if [[ "$(grep -Fxc '    version: !file ../openapi.yaml#info.version' konnect/dev.yaml)" -ne 1 ||
      "$(grep -Fxc '        version: !file ../openapi.yaml#info.version' konnect/dev.yaml)" -ne 1 ||
      "$(grep -Fxc '        spec: !file ../openapi.yaml' konnect/dev.yaml)" -ne 1 ]]; then
  echo "konnect/dev.yaml must use openapi.yaml as its API version and specification" >&2
  exit 1
fi

production_version="$(
  sed -nE 's/^    version:[[:space:]]*([^[:space:]#]+)[[:space:]]*$/\1/p' konnect/prod.yaml
)"
if [[ -z "${production_version}" || "${production_version}" == *$'\n'* ]]; then
  echo "konnect/prod.yaml must declare exactly one API-level production version" >&2
  exit 1
fi
if [[ ! "${production_version}" =~ ${STABLE_VERSION_PATTERN} ]]; then
  echo "production version ${production_version} must be a stable semantic version" >&2
  exit 1
fi

production_spec="openapi/versions/${production_version}.yaml"
if [[ ! -f "${production_spec}" ]]; then
  echo "current production specification ${production_spec} does not exist" >&2
  exit 1
fi

shopt -s nullglob
release_specs=(openapi/versions/*.yaml)
if [[ "${#release_specs[@]}" -eq 0 ]]; then
  echo "openapi/versions must contain at least one stable release" >&2
  exit 1
fi

for release_spec in "${release_specs[@]}"; do
  filename_version="$(basename "${release_spec}" .yaml)"
  declared_version="$(spec_version "${release_spec}")"
  if [[ ! "${filename_version}" =~ ${STABLE_VERSION_PATTERN} ]]; then
    echo "${release_spec} must use a stable semantic-version filename" >&2
    exit 1
  fi
  if [[ "${declared_version}" != "${filename_version}" ]]; then
    echo "${release_spec} declares version ${declared_version}; expected ${filename_version}" >&2
    exit 1
  fi
  grep -Fq "version: !file ../${release_spec}#info.version" konnect/prod.yaml || {
    echo "konnect/prod.yaml does not declare release ${filename_version}" >&2
    exit 1
  }
  grep -Fq "spec: !file ../${release_spec}" konnect/prod.yaml || {
    echo "konnect/prod.yaml does not include the spec for release ${filename_version}" >&2
    exit 1
  }
done

while IFS= read -r declared_spec; do
  if [[ ! "${declared_spec}" =~ ${PRODUCTION_SPEC_PATTERN} ]]; then
    echo "production specifications must be stable files under openapi/versions: ${declared_spec}" >&2
    exit 1
  fi
  resolved_spec="${declared_spec#../}"
  if [[ ! -f "${resolved_spec}" ]]; then
    echo "konnect/prod.yaml references missing specification ${resolved_spec}" >&2
    exit 1
  fi
done < <(sed -nE 's/^[[:space:]]+spec:[[:space:]]*!file[[:space:]]+([^[:space:]#]+).*$/\1/p' konnect/prod.yaml)

if [[ -n "${BASE_SHA}" ]]; then
  if ! git cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
    echo "cannot validate release immutability: base commit ${BASE_SHA} is unavailable" >&2
    exit 1
  fi
  changed_releases="$(git diff --name-only --diff-filter=MDRT "${BASE_SHA}" -- openapi/versions)"
  if [[ -n "${changed_releases}" ]]; then
    echo "released OpenAPI specifications are immutable:" >&2
    echo "${changed_releases}" >&2
    exit 1
  fi
fi
