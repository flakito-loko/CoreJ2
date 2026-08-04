#!/usr/bin/env bash
# Phase 1.5 — Build macOS JDK image from openjdk/mobile (host-linkable libjvm).
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[[ -d "${OJDK_SRC_DIR}" ]] || ojdk_die "sources missing — run 01-fetch-sources.sh first"

ROOT_CACHE="${OJDK_CACHE_DIR}"
export PATH="${ROOT_CACHE}/autoconf-prefix/bin:${ROOT_CACHE}/m4-prefix/bin:${PATH:-}"
if command -v xcrun >/dev/null 2>&1; then
  if metal_bin="$(xcrun --find metal 2>/dev/null)"; then
    export PATH="$(dirname "${metal_bin}"):${PATH}"
  fi
fi

BOOT_JDK="${BOOT_JDK_HOME:-}"
if [[ -z "${BOOT_JDK}" ]]; then
  if [[ -x "${ROOT_CACHE}/jdk-26.0.2+10/Contents/Home/bin/java" ]]; then
    BOOT_JDK="${ROOT_CACHE}/jdk-26.0.2+10/Contents/Home"
  elif [[ -x "${ROOT_CACHE}/jdk-24.0.2+12/Contents/Home/bin/java" ]]; then
    BOOT_JDK="${ROOT_CACHE}/jdk-24.0.2+12/Contents/Home"
  else
    BOOT_JDK="$(ojdk_resolve_boot_jdk || true)"
  fi
fi
[[ -n "${BOOT_JDK}" && -x "${BOOT_JDK}/bin/java" ]] || ojdk_die "Boot JDK required"
export JAVA_HOME="${BOOT_JDK}"
export PATH="${JAVA_HOME}/bin:${PATH}"

cd "${OJDK_SRC_DIR}"

# Discover macOS conf name (typical: macosx-aarch64-server-release)
CONF=""
if [[ -d build ]]; then
  CONF="$(find build -maxdepth 1 -type d -name 'macosx-*-server-release' 2>/dev/null | head -1 | xargs -I{} basename {} || true)"
fi
if [[ -z "${CONF}" ]]; then
  CONF="$(ls -1 build 2>/dev/null | grep -E 'macosx-.*-release' | head -1 || true)"
fi
[[ -n "${CONF}" ]] || ojdk_die "No macOS conf under build/ — run 03b-configure-macos-host.sh first"

BUILD_LOG="${OJDK_OUT_DIR}/build-macos-host.log"
ojdk_log "make CONF=${CONF} images (OpenJDK Mobile macOS host)"
ojdk_log "Log: ${BUILD_LOG}"

make CONF="${CONF}" images 2>&1 | tee "${BUILD_LOG}"

JDK_IMAGE="$(find "build/${CONF}/images" -maxdepth 2 -type d -name 'jdk' 2>/dev/null | head -1 || true)"
[[ -n "${JDK_IMAGE}" && -d "${JDK_IMAGE}" ]] || ojdk_die "jdk image missing under build/${CONF}/images"

# Resolve to absolute path for staging scripts.
JDK_IMAGE="$(cd "${JDK_IMAGE}" && pwd)"

LIBJVM="$(find "${JDK_IMAGE}" -name 'libjvm.dylib' | head -1 || true)"
[[ -f "${LIBJVM}" ]] || ojdk_die "libjvm.dylib missing in ${JDK_IMAGE}"

ojdk_log "macOS Mobile image OK: ${JDK_IMAGE}"
ojdk_log "libjvm: ${LIBJVM}"
echo "${CONF}" > "${OJDK_OUT_DIR}/last-macos-conf.txt"
echo "${JDK_IMAGE}" > "${OJDK_OUT_DIR}/last-macos-jdk-image.txt"
echo "${LIBJVM}" > "${OJDK_OUT_DIR}/last-macos-libjvm.txt"

ojdk_log "Next: 05b-stage-macos-host.sh"
