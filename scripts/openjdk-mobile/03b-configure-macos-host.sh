#!/usr/bin/env bash
# Phase 1.5 — Configure openjdk/mobile for macOS host (linkable into Phase-1 harness).
# Upstream requires a successful macOS build before iOS. Does not touch App Target.
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

[[ -d "${OJDK_SRC_DIR}" ]] || ojdk_die "sources missing — run 01-fetch-sources.sh first"

ROOT_CACHE="${OJDK_CACHE_DIR}"
export PATH="${ROOT_CACHE}/autoconf-prefix/bin:${ROOT_CACHE}/m4-prefix/bin:${PATH:-}"
# Xcode 26+ may keep `metal` outside the default PATH.
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
[[ -n "${BOOT_JDK}" && -x "${BOOT_JDK}/bin/java" ]] || ojdk_die "Boot JDK ${BOOT_JDK_MAJOR} required"

export JAVA_HOME="${BOOT_JDK}"
export PATH="${JAVA_HOME}/bin:${PATH}"

cd "${OJDK_SRC_DIR}"
chmod +x ./configure 2>/dev/null || true
[[ -f ./configure ]] || ojdk_die "missing configure"

CONFIGURE_LOG="${OJDK_OUT_DIR}/configure-macos-host.log"
ojdk_log "Configuring openjdk/mobile for macOS host (Phase 1.5)"
ojdk_log "  boot-jdk=${BOOT_JDK}"
ojdk_log "  log=${CONFIGURE_LOG}"

bash ./configure \
  --disable-warnings-as-errors \
  --with-boot-jdk="${BOOT_JDK}" \
  --with-jvm-variants=server \
  2>&1 | tee "${CONFIGURE_LOG}"

# OpenJDK prints success and creates conf dir on success.
if [[ ! -d "${OJDK_SRC_DIR}/build/macosx-aarch64-server-release" ]] \
   && ! ls -d "${OJDK_SRC_DIR}"/build/macosx-*-server-release >/dev/null 2>&1; then
  ojdk_die "configure failed — see ${CONFIGURE_LOG}"
fi

ojdk_log "Configure (macOS host) finished. Next: 04b-build-macos-host.sh"
