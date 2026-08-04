#!/usr/bin/env bash
# Phase 1.5 — Stage macOS OpenJDK Mobile image for the Phase-1 harness.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ojdk_ensure_dirs

JDK_IMAGE=""
if [[ -f "${OJDK_OUT_DIR}/last-macos-jdk-image.txt" ]]; then
  JDK_IMAGE="$(tr -d '[:space:]' < "${OJDK_OUT_DIR}/last-macos-jdk-image.txt")"
fi
[[ -n "${JDK_IMAGE}" && -d "${JDK_IMAGE}" ]] || ojdk_die "missing macOS jdk image — run 04b-build-macos-host.sh"

LIBJVM="$(find "${JDK_IMAGE}" -name 'libjvm.dylib' | head -1 || true)"
[[ -f "${LIBJVM}" ]] || ojdk_die "libjvm.dylib missing"

COMMIT="unknown"
if [[ -d "${OJDK_SRC_DIR}/.git" ]]; then
  COMMIT="$(git -C "${OJDK_SRC_DIR}" rev-parse HEAD)"
fi
SHORT="${COMMIT:0:12}"
LABEL="macos-host-${SHORT}"
DEST="${STAGED_ROOT}/${LABEL}"

ojdk_log "Staging macOS Mobile JDK → ${DEST}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
# Keep a self-contained java.home for the harness.
rsync -a --delete "${JDK_IMAGE}/" "${DEST}/jdk/" 2>/dev/null \
  || { mkdir -p "${DEST}/jdk"; cp -R "${JDK_IMAGE}/." "${DEST}/jdk/"; }

STAGED_LIBJVM="$(find "${DEST}/jdk" -name 'libjvm.dylib' | head -1)"
LIBJVM_SHA="$(ojdk_sha256_file "${STAGED_LIBJVM}")"
LIBJVM_BYTES="$(wc -c < "${STAGED_LIBJVM}" | tr -d ' ')"

MANIFEST="${MANIFESTS_DIR}/manifest-${LABEL}.env"
cat > "${MANIFEST}" <<EOF
MANIFEST_SCHEMA_VERSION="1"
BUILT_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OPENJDK_MOBILE_GIT_URL="${OPENJDK_MOBILE_GIT_URL}"
OPENJDK_MOBILE_REF="${OPENJDK_MOBILE_REF}"
OPENJDK_MOBILE_COMMIT_SHA="${COMMIT}"
OPENJDK_PROFILE="macos-host-server"
LIBJVM_SHA256="${LIBJVM_SHA}"
LIBJVM_BYTES="${LIBJVM_BYTES}"
JAVA_HOME_RELPATH="artifacts/openjdk-mobile/staged/${LABEL}/jdk"
LIBJVM_RELPATH_IN_STAGE="jdk/lib/server/libjvm.dylib"
NOTES="Phase 1.5 host-linkable image from openjdk/mobile (not App Target)."
EOF

cp "${MANIFEST}" "${DEST}/manifest.env"
echo "${LIBJVM_SHA}" > "${DEST}/libjvm.sha256"
ln -sfn "${LABEL}" "${STAGED_ROOT}/current-macos"
# Also point current to macos for Phase 1.5 harness discovery when iOS not present.
if [[ ! -e "${STAGED_ROOT}/current" ]] || [[ -L "${STAGED_ROOT}/current" ]]; then
  ln -sfn "${LABEL}" "${STAGED_ROOT}/current"
fi

ojdk_log "Staged ${LIBJVM_BYTES} bytes libjvm sha256=${LIBJVM_SHA}"
ojdk_log "Pointer: ${STAGED_ROOT}/current-macos → ${LABEL}"
