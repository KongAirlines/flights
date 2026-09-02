#!/usr/bin/env bash
set -euo pipefail

readonly RELEASE_VERSION="${1:-}"
readonly NEXT_DEVELOPMENT_VERSION="${2:-}"
readonly STABLE_VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$'
readonly BASE_SHA="$(git rev-parse HEAD)"

if [[ ! "${RELEASE_VERSION}" =~ ${STABLE_VERSION_PATTERN} ]]; then
  echo "usage: $0 <release-version> <next-development-version>" >&2
  echo "both versions must be stable semantic versions such as 0.2.0" >&2
  exit 1
fi
if [[ ! "${NEXT_DEVELOPMENT_VERSION}" =~ ${STABLE_VERSION_PATTERN} ]]; then
  echo "next development version must be a stable semantic version such as 0.3.0" >&2
  exit 1
fi
if [[ "${RELEASE_VERSION}" == "${NEXT_DEVELOPMENT_VERSION}" ]]; then
  echo "next development version must differ from the release version" >&2
  exit 1
fi

IFS=. read -r release_major release_minor release_patch <<< "${RELEASE_VERSION}"
IFS=. read -r next_major next_minor next_patch <<< "${NEXT_DEVELOPMENT_VERSION}"
if (( next_major < release_major ||
      (next_major == release_major && next_minor < release_minor) ||
      (next_major == release_major && next_minor == release_minor && next_patch <= release_patch) )); then
  echo "next development version must be greater than the release version" >&2
  exit 1
fi

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

replace_spec_version() {
  local input="$1"
  local output="$2"
  local version="$3"
  awk -v version="${version}" '
    /^info:[[:space:]]*$/ { in_info = 1 }
    in_info && /^[[:space:]]+version:[[:space:]]*/ && ! replaced {
      prefix = $0
      sub(/version:.*/, "version: ", prefix)
      print prefix version
      replaced = 1
      next
    }
    { print }
    END { if (! replaced) exit 1 }
  ' "${input}" > "${output}"
}

current_development_version="$(spec_version openapi.yaml)"
if [[ ! "${current_development_version}" =~ ^${RELEASE_VERSION//./\.}-beta\.[0-9]+$ ]]; then
  echo "openapi.yaml is ${current_development_version}; expected ${RELEASE_VERSION}-beta.N" >&2
  exit 1
fi

release_spec="openapi/versions/${RELEASE_VERSION}.yaml"
if [[ -e "${release_spec}" ]]; then
  echo "${release_spec} already exists; released specifications cannot be overwritten" >&2
  exit 1
fi

prod_api_ref="$(sed -nE 's/^  - ref:[[:space:]]*([^[:space:]]+-prod-api)[[:space:]]*$/\1/p' konnect/prod.yaml)"
if [[ -z "${prod_api_ref}" || "${prod_api_ref}" == *$'\n'* ]]; then
  echo "konnect/prod.yaml must declare exactly one production API ref" >&2
  exit 1
fi
release_ref="${prod_api_ref%-api}-${RELEASE_VERSION//./-}"

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
replace_spec_version openapi.yaml "${work_dir}/release.yaml" "${RELEASE_VERSION}"
replace_spec_version openapi.yaml "${work_dir}/openapi.yaml" "${NEXT_DEVELOPMENT_VERSION}-beta.1"
awk \
  -v release_version="${RELEASE_VERSION}" \
  -v release_ref="${release_ref}" \
  -v release_spec="${release_spec}" '
    /^    version:[[:space:]]*/ && ! current_replaced {
      print "    version: " release_version
      current_replaced = 1
      next
    }
    /^    publications:[[:space:]]*$/ && ! release_added {
      print "      - ref: " release_ref
      print "        version: !file ../" release_spec "#info.version"
      print "        spec: !file ../" release_spec
      release_added = 1
    }
    { print }
    END { if (! current_replaced || ! release_added) exit 1 }
  ' konnect/prod.yaml > "${work_dir}/prod.yaml"

mv "${work_dir}/release.yaml" "${release_spec}"
mv "${work_dir}/openapi.yaml" openapi.yaml
mv "${work_dir}/prod.yaml" konnect/prod.yaml

./scripts/generate-gateway.sh
RELEASE_BASE_SHA="${BASE_SHA}" ./scripts/lint-reference-platform.sh

echo "Prepared ${RELEASE_VERSION} for production and advanced development to ${NEXT_DEVELOPMENT_VERSION}-beta.1"
