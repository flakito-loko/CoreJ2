#!/usr/bin/env bash
# 02 — Download and extract Gluon mobile-support zip (libffi + cups).
# Fase 0A — cache only; not linked into the App Target.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ojdk_require_cmd unzip
ojdk_ensure_dirs

ZIP_PATH="${OJDK_CACHE_DIR}/${GLUON_MOBILE_SUPPORT_ZIP_NAME}"

download() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 -o "${dest}.partial" "${url}"
    mv "${dest}.partial" "${dest}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${dest}.partial" "${url}"
    mv "${dest}.partial" "${dest}"
  else
    ojdk_die "curl or wget required"
  fi
}

if [[ ! -f "${ZIP_PATH}" ]]; then
  ojdk_log "Downloading ${GLUON_MOBILE_SUPPORT_URL}"
  download "${GLUON_MOBILE_SUPPORT_URL}" "${ZIP_PATH}"
else
  ojdk_log "Using cached zip ${ZIP_PATH}"
fi

ACTUAL_SHA="$(ojdk_sha256_file "${ZIP_PATH}")"
ojdk_log "SHA256(${GLUON_MOBILE_SUPPORT_ZIP_NAME})=${ACTUAL_SHA}"
echo "${ACTUAL_SHA}" > "${OJDK_OUT_DIR}/last-support-sha256.txt"

if [[ -n "${GLUON_MOBILE_SUPPORT_SHA256}" ]]; then
  if [[ "${ACTUAL_SHA}" != "${GLUON_MOBILE_SUPPORT_SHA256}" ]]; then
    ojdk_die "SHA256 mismatch for support zip (expected ${GLUON_MOBILE_SUPPORT_SHA256}, got ${ACTUAL_SHA})"
  fi
  ojdk_log "SHA256 matches versions.env pin"
else
  ojdk_warn "No pin in versions.env — record this value:"
  echo "  GLUON_MOBILE_SUPPORT_SHA256=\"${ACTUAL_SHA}\""
fi

ojdk_log "Extracting to ${OJDK_SUPPORT_EXTRACTED}"
rm -rf "${OJDK_SUPPORT_EXTRACTED}"
mkdir -p "${OJDK_SUPPORT_EXTRACTED}"
unzip -q -o "${ZIP_PATH}" -d "${OJDK_SUPPORT_EXTRACTED}"

# Normalize: some zips nest a single top-level directory.
if [[ ! -d "${OJDK_SUPPORT_EXTRACTED}/libffi" ]]; then
  nested="$(find "${OJDK_SUPPORT_EXTRACTED}" -maxdepth 2 -type d -name libffi 2>/dev/null | head -1 || true)"
  if [[ -n "${nested}" ]]; then
    support_root="$(cd "$(dirname "${nested}")" && pwd)"
    ojdk_log "Detected nested support root: ${support_root}"
    # Re-home extracted tree to a stable path for configure scripts.
    tmp_home="${OJDK_SUPPORT_DIR}/.extract-tmp"
    rm -rf "${tmp_home}"
    mv "${support_root}" "${tmp_home}"
    rm -rf "${OJDK_SUPPORT_EXTRACTED}"
    mv "${tmp_home}" "${OJDK_SUPPORT_EXTRACTED}"
  fi
fi

[[ -d "${OJDK_SUPPORT_EXTRACTED}/libffi/include" ]] \
  || ojdk_die "missing libffi/include under ${OJDK_SUPPORT_EXTRACTED}"
[[ -d "${OJDK_SUPPORT_EXTRACTED}/libffi/libs" ]] \
  || ojdk_die "missing libffi/libs under ${OJDK_SUPPORT_EXTRACTED}"
[[ -d "${OJDK_SUPPORT_EXTRACTED}/cups-2.3.6" ]] \
  || ojdk_die "missing cups-2.3.6 under ${OJDK_SUPPORT_EXTRACTED} (adjust versions/docs if Gluon layout changes)"

ojdk_log "Support tree ready at ${OJDK_SUPPORT_EXTRACTED}"
