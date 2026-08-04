#!/usr/bin/env bash
# Shared paths and helpers for OpenJDK Mobile Fase 0A scripts.
# Does not touch Xcode, FreeJ2ME, Bridge, Host, Adapter, or App Target.

set -euo pipefail

_OJDK_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_OJDK_SCRIPTS_DIR}/../.." && pwd)"

OJDK_ROOT="${REPO_ROOT}/ThirdParty/OpenJDKMobile"
VERSIONS_ENV="${OJDK_ROOT}/versions.env"
OJDK_CACHE_DIR="${OJDK_ROOT}/cache"
OJDK_SRC_PARENT="${OJDK_ROOT}/src"
OJDK_SRC_DIR="${OJDK_SRC_PARENT}/mobile"
OJDK_SUPPORT_DIR="${OJDK_ROOT}/support"
OJDK_SUPPORT_EXTRACTED="${OJDK_SUPPORT_DIR}/mobile-support"
OJDK_OUT_DIR="${OJDK_ROOT}/out"

ARTIFACTS_ROOT="${REPO_ROOT}/artifacts/openjdk-mobile"
STAGED_ROOT="${ARTIFACTS_ROOT}/staged"
MANIFESTS_DIR="${ARTIFACTS_ROOT}/manifests"

if [[ ! -f "${VERSIONS_ENV}" ]]; then
  echo "error: missing ${VERSIONS_ENV}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${VERSIONS_ENV}"

ojdk_log() {
  printf '==> %s\n' "$*"
}

ojdk_warn() {
  printf 'warning: %s\n' "$*" >&2
}

ojdk_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

ojdk_require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || ojdk_die "required command not found: ${cmd}"
}

ojdk_sha256_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${path}" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  else
    ojdk_die "neither shasum nor sha256sum found"
  fi
}

ojdk_resolve_boot_jdk() {
  if [[ -n "${BOOT_JDK_HOME:-}" && -x "${BOOT_JDK_HOME}/bin/java" ]]; then
    printf '%s\n' "${BOOT_JDK_HOME}"
    return 0
  fi
  if [[ -x /usr/libexec/java_home ]]; then
    /usr/libexec/java_home -v "${BOOT_JDK_MAJOR}" 2>/dev/null && return 0
  fi
  return 1
}

ojdk_iphoneos_sdk() {
  xcrun --sdk iphoneos --show-sdk-path
}

ojdk_ensure_dirs() {
  mkdir -p \
    "${OJDK_CACHE_DIR}" \
    "${OJDK_SRC_PARENT}" \
    "${OJDK_SUPPORT_DIR}" \
    "${OJDK_OUT_DIR}" \
    "${STAGED_ROOT}" \
    "${MANIFESTS_DIR}"
}
