#!/usr/bin/env bash
# 05 — Stage static libs + write a reproducibility manifest (Fase 0A).
# Copies into artifacts/openjdk-mobile/staged — still not linked to App Target.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ojdk_ensure_dirs

STATIC_SRC="${OJDK_SRC_DIR}/${OPENJDK_STATIC_LIBS_RELDIR}"
LIBJVM_SRC="${OJDK_SRC_DIR}/${OPENJDK_LIBJVM_RELPATH}"

[[ -f "${LIBJVM_SRC}" ]] || ojdk_die "missing ${LIBJVM_SRC} — run 04-build-static-libs.sh first"
[[ -d "${STATIC_SRC}" ]] || ojdk_die "missing ${STATIC_SRC}"

COMMIT="unknown"
if [[ -d "${OJDK_SRC_DIR}/.git" ]]; then
  COMMIT="$(git -C "${OJDK_SRC_DIR}" rev-parse HEAD)"
fi
SHORT="${COMMIT:0:12}"
LABEL="${OPENJDK_CONF_NAME}-${SHORT}"
DEST="${STAGED_ROOT}/${LABEL}"

ojdk_log "Staging → ${DEST}"
rm -rf "${DEST}"
mkdir -p "${DEST}"
# Preserve relative layout under static-libs/
rsync -a --delete "${STATIC_SRC}/" "${DEST}/static-libs/" 2>/dev/null \
  || { mkdir -p "${DEST}/static-libs"; cp -R "${STATIC_SRC}/." "${DEST}/static-libs/"; }

LIBJVM_STAGED="${DEST}/static-libs/lib/zero/libjvm.a"
[[ -f "${LIBJVM_STAGED}" ]] || {
  # Fallback: find libjvm.a under staged tree
  LIBJVM_STAGED="$(find "${DEST}" -name libjvm.a | head -1 || true)"
}
[[ -n "${LIBJVM_STAGED}" && -f "${LIBJVM_STAGED}" ]] || ojdk_die "libjvm.a not found after staging"

LIBJVM_SHA="$(ojdk_sha256_file "${LIBJVM_STAGED}")"
LIBJVM_BYTES="$(wc -c < "${LIBJVM_STAGED}" | tr -d ' ')"

SUPPORT_SHA="${GLUON_MOBILE_SUPPORT_SHA256}"
if [[ -z "${SUPPORT_SHA}" && -f "${OJDK_OUT_DIR}/last-support-sha256.txt" ]]; then
  SUPPORT_SHA="$(tr -d '[:space:]' < "${OJDK_OUT_DIR}/last-support-sha256.txt")"
fi

boot_home="$(ojdk_resolve_boot_jdk || true)"
sdk_path="$(ojdk_iphoneos_sdk 2>/dev/null || true)"
xcode_ver="$(xcodebuild -version 2>/dev/null | tr '\n' ' ' || true)"
sdk_ver="$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || true)"
boot_ver="$("${boot_home}/bin/java" -version 2>&1 | head -1 || true)"

MANIFEST="${MANIFESTS_DIR}/manifest-${LABEL}.env"
cat > "${MANIFEST}" <<EOF
MANIFEST_SCHEMA_VERSION="1"
BUILT_AT_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OPENJDK_MOBILE_GIT_URL="${OPENJDK_MOBILE_GIT_URL}"
OPENJDK_MOBILE_REF="${OPENJDK_MOBILE_REF}"
OPENJDK_MOBILE_COMMIT_SHA="${COMMIT}"
OPENJDK_CONF_NAME="${OPENJDK_CONF_NAME}"
OPENJDK_MAKE_TARGET="${OPENJDK_MAKE_TARGET}"
GLUON_MOBILE_SUPPORT_ZIP_NAME="${GLUON_MOBILE_SUPPORT_ZIP_NAME}"
GLUON_MOBILE_SUPPORT_SHA256="${SUPPORT_SHA}"
LIBJVM_SHA256="${LIBJVM_SHA}"
LIBJVM_BYTES="${LIBJVM_BYTES}"
XCODE_SELECT_PATH="$(xcode-select -p 2>/dev/null || true)"
XCODE_VERSION="${xcode_ver}"
IPHONEOS_SDK_PATH="${sdk_path}"
IPHONEOS_SDK_VERSION="${sdk_ver}"
BOOT_JDK_HOME="${boot_home}"
BOOT_JDK_VERSION="${boot_ver}"
HOST_UNAME="$(uname -a)"
STAGED_DIR_RELPATH="artifacts/openjdk-mobile/staged/${LABEL}"
LIBJVM_RELPATH_IN_STAGE="static-libs/lib/zero/libjvm.a"
NOTES="Fase 0A: staged only; not linked to App Target."
EOF

# Convenient pointers
ln -sfn "${LABEL}" "${STAGED_ROOT}/current" 2>/dev/null \
  || { rm -f "${STAGED_ROOT}/current"; ln -s "${LABEL}" "${STAGED_ROOT}/current"; }

echo "${LIBJVM_SHA}" > "${DEST}/libjvm.sha256"
cp "${MANIFEST}" "${DEST}/manifest.env"

ojdk_log "Staged libjvm.a (${LIBJVM_BYTES} bytes)"
ojdk_log "SHA256=${LIBJVM_SHA}"
ojdk_log "Manifest: ${MANIFEST}"
ojdk_log "Pointer: ${STAGED_ROOT}/current → ${LABEL}"
