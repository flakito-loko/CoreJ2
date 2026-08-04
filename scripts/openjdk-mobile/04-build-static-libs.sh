#!/usr/bin/env bash
# 04 — Build static-libs-image (Zero / ios-aarch64-zero-release).
# Fase 0A — long-running; output stays under ThirdParty clone, then staged by 05.
# Does not modify Xcode or App Target.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[[ -d "${OJDK_SRC_DIR}" ]] || ojdk_die "sources missing — run 01-fetch-sources.sh first"

boot_home="$(ojdk_resolve_boot_jdk)" || ojdk_die "Boot JDK ${BOOT_JDK_MAJOR} not found"
export JAVA_HOME="${boot_home}"
export PATH="${JAVA_HOME}/bin:${PATH}"

cd "${OJDK_SRC_DIR}"

BUILD_LOG="${OJDK_OUT_DIR}/build-static-libs.log"
ojdk_log "make CONF=${OPENJDK_CONF_NAME} ${OPENJDK_MAKE_TARGET}"
ojdk_log "Log: ${BUILD_LOG}"
ojdk_log "This can take a long time on first run."

make CONF="${OPENJDK_CONF_NAME}" "${OPENJDK_MAKE_TARGET}" 2>&1 | tee "${BUILD_LOG}"

LIBJVM="${OJDK_SRC_DIR}/${OPENJDK_LIBJVM_RELPATH}"
if [[ ! -f "${LIBJVM}" ]]; then
  ojdk_die "expected artifact missing: ${LIBJVM}"
fi

ojdk_log "Build OK: ${LIBJVM}"
ojdk_log "Next: 05-stage-artifacts.sh"
