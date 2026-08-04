#!/usr/bin/env bash
# 06 — Verify staged OpenJDK Mobile artifacts against manifest (Fase 0A).

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

LABEL_OR_PATH="${1:-}"
if [[ -z "${LABEL_OR_PATH}" ]]; then
  if [[ -L "${STAGED_ROOT}/current" || -d "${STAGED_ROOT}/current" ]]; then
    STAGE_DIR="${STAGED_ROOT}/current"
  else
    ojdk_die "usage: $0 <stage-label|stage-dir>   (or create staged/current via 05-stage-artifacts.sh)"
  fi
elif [[ -d "${LABEL_OR_PATH}" ]]; then
  STAGE_DIR="${LABEL_OR_PATH}"
else
  STAGE_DIR="${STAGED_ROOT}/${LABEL_OR_PATH}"
fi

[[ -d "${STAGE_DIR}" ]] || ojdk_die "stage dir not found: ${STAGE_DIR}"

MANIFEST="${STAGE_DIR}/manifest.env"
if [[ ! -f "${MANIFEST}" ]]; then
  # Fall back to manifests/ by basename
  base="$(basename "$(cd "${STAGE_DIR}" && pwd)")"
  MANIFEST="${MANIFESTS_DIR}/manifest-${base}.env"
fi
[[ -f "${MANIFEST}" ]] || ojdk_die "manifest not found for ${STAGE_DIR}"

# shellcheck disable=SC1090
source "${MANIFEST}"

LIBJVM=""
if [[ -n "${LIBJVM_RELPATH_IN_STAGE:-}" && -f "${STAGE_DIR}/${LIBJVM_RELPATH_IN_STAGE}" ]]; then
  LIBJVM="${STAGE_DIR}/${LIBJVM_RELPATH_IN_STAGE}"
else
  LIBJVM="$(find "${STAGE_DIR}" -name libjvm.a | head -1 || true)"
fi
[[ -f "${LIBJVM}" ]] || ojdk_die "libjvm.a missing under ${STAGE_DIR}"

ACTUAL="$(ojdk_sha256_file "${LIBJVM}")"
ojdk_log "libjvm.a → ${LIBJVM}"
ojdk_log "actual SHA256=${ACTUAL}"

if [[ -n "${LIBJVM_SHA256:-}" ]]; then
  if [[ "${ACTUAL}" != "${LIBJVM_SHA256}" ]]; then
    ojdk_die "SHA256 mismatch (manifest ${LIBJVM_SHA256})"
  fi
  ojdk_log "SHA256 matches manifest"
else
  ojdk_warn "manifest has empty LIBJVM_SHA256"
fi

BYTES="$(wc -c < "${LIBJVM}" | tr -d ' ')"
ojdk_log "size=${BYTES} bytes (manifest LIBJVM_BYTES=${LIBJVM_BYTES:-unset})"
ojdk_log "commit=${OPENJDK_MOBILE_COMMIT_SHA:-unset} conf=${OPENJDK_CONF_NAME:-unset}"
ojdk_log "Verify OK (Fase 0A — still not linked to App Target)"
