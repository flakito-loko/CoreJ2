#!/usr/bin/env bash
# 03 — Configure OpenJDK Mobile for iOS device (aarch64, Zero default).
# Fase 0A — does not link into App Target.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[[ -d "${OJDK_SRC_DIR}" ]] || ojdk_die "sources missing — run 01-fetch-sources.sh first"
[[ -d "${OJDK_SUPPORT_EXTRACTED}/libffi" ]] || ojdk_die "support missing — run 02-fetch-support.sh first"
[[ -f "${OJDK_SRC_DIR}/configure" ]] || ojdk_die "missing ${OJDK_SRC_DIR}/configure — incomplete clone?"

boot_home="$(ojdk_resolve_boot_jdk)" || ojdk_die "Boot JDK ${BOOT_JDK_MAJOR} not found (set BOOT_JDK_HOME)"
sdk_path="$(ojdk_iphoneos_sdk)" || ojdk_die "iPhoneOS SDK not found"

export JAVA_HOME="${boot_home}"
export PATH="${JAVA_HOME}/bin:${PATH}"

LIBFFI_INC="${OJDK_SUPPORT_EXTRACTED}/libffi/include"
LIBFFI_LIB="${OJDK_SUPPORT_EXTRACTED}/libffi/libs"
CUPS_INC="${OJDK_SUPPORT_EXTRACTED}/cups-2.3.6"

[[ -d "${LIBFFI_INC}" ]] || ojdk_die "missing ${LIBFFI_INC}"
[[ -d "${LIBFFI_LIB}" ]] || ojdk_die "missing ${LIBFFI_LIB}"
[[ -d "${CUPS_INC}" ]] || ojdk_die "missing ${CUPS_INC}"
[[ -d "${sdk_path}" ]] || ojdk_die "missing SDK ${sdk_path}"

cd "${OJDK_SRC_DIR}"
chmod +x ./configure 2>/dev/null || true

CONFIGURE_LOG="${OJDK_OUT_DIR}/configure-ios-device.log"
ojdk_log "Running configure → log ${CONFIGURE_LOG}"
ojdk_log "  target=${OPENJDK_TARGET}"
ojdk_log "  sysroot=${sdk_path}"
ojdk_log "  boot-jdk=${boot_home}"

# Mirrors openjdk/mobile README (device). Upstream README historically omitted a
# line-continuation backslash after --with-cups-include; this invocation is valid.
bash ./configure \
  --disable-warnings-as-errors \
  --openjdk-target="${OPENJDK_TARGET}" \
  --with-boot-jdk="${boot_home}" \
  --with-libffi-include="${LIBFFI_INC}" \
  --with-libffi-lib="${LIBFFI_LIB}" \
  --with-cups-include="${CUPS_INC}" \
  --with-sysroot="${sdk_path}" \
  2>&1 | tee "${CONFIGURE_LOG}"

ojdk_log "Configure finished. Next: 04-build-static-libs.sh"
