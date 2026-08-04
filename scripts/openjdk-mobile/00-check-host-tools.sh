#!/usr/bin/env bash
# 00 — Verify host tooling for OpenJDK Mobile (Fase 0A).
# No network required. Does not build or link the JVM.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ojdk_ensure_dirs

failures=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf '  [ok] %s\n' "${label}"
  else
    printf '  [FAIL] %s\n' "${label}"
    failures=$((failures + 1))
  fi
}

ojdk_log "Checking host tools for OpenJDK Mobile (device / Zero path)"

# Important: do not put shell redirections on the `check ...` invocation line;
# they would silence the [ok]/[FAIL] lines and hide failures.
check "xcode-select path" bash -c '[[ -n "$(xcode-select -p 2>/dev/null || true)" ]]'
check "xcrun available" bash -c 'command -v xcrun >/dev/null'
check "iPhoneOS SDK" bash -c 'sdk="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)" && [[ -d "$sdk" ]]'
check "clang (Xcode)" bash -c 'xcrun --sdk iphoneos --find clang >/dev/null 2>&1'
check "git" bash -c 'command -v git >/dev/null'
check "make" bash -c 'command -v make >/dev/null'
check "autoconf (autoreconf)" bash -c 'command -v autoreconf >/dev/null'
check "curl or wget" bash -c 'command -v curl >/dev/null || command -v wget >/dev/null'
check "unzip" bash -c 'command -v unzip >/dev/null'
check "shasum/sha256sum" bash -c 'command -v shasum >/dev/null || command -v sha256sum >/dev/null'

if boot_home="$(ojdk_resolve_boot_jdk)"; then
  printf '  [ok] Boot JDK %s → %s\n' "${BOOT_JDK_MAJOR}" "${boot_home}"
  "${boot_home}/bin/java" -version 2>&1 | sed 's/^/       /' || true
else
  printf '  [FAIL] Boot JDK %s (set BOOT_JDK_HOME or install JDK %s)\n' "${BOOT_JDK_MAJOR}" "${BOOT_JDK_MAJOR}"
  failures=$((failures + 1))
fi

echo
ojdk_log "Pinned configuration (${VERSIONS_ENV})"
echo "  OPENJDK_MOBILE_GIT_URL=${OPENJDK_MOBILE_GIT_URL}"
echo "  OPENJDK_MOBILE_REF=${OPENJDK_MOBILE_REF}"
echo "  GLUON_MOBILE_SUPPORT_URL=${GLUON_MOBILE_SUPPORT_URL}"
echo "  OPENJDK_CONF_NAME=${OPENJDK_CONF_NAME}"
echo "  OPENJDK_MAKE_TARGET=${OPENJDK_MAKE_TARGET}"
if [[ -z "${GLUON_MOBILE_SUPPORT_SHA256}" ]]; then
  ojdk_warn "GLUON_MOBILE_SUPPORT_SHA256 is empty — pin after first download (02-fetch-support.sh)."
fi
if [[ "${OPENJDK_MOBILE_REF}" == "master" || "${OPENJDK_MOBILE_REF}" == "main" ]]; then
  ojdk_warn "OPENJDK_MOBILE_REF=${OPENJDK_MOBILE_REF} is a moving branch — pin a commit SHA for reproducibility."
fi

echo
if [[ "${failures}" -ne 0 ]]; then
  ojdk_die "${failures} check(s) failed. See docs/Architecture/OPENJDK_MOBILE_BUILD.md"
fi

ojdk_log "Host tooling OK (Fase 0A). Ready for fetch/configure/build scripts."
