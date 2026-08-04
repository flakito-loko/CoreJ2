#!/usr/bin/env bash
# Phase 1.5 — Build OpenJDK Mobile (macOS host from openjdk/mobile) via Fase 0A kit extensions.
# Does not modify App Target / EmbeddedJVMManager / Bridge / Host / Adapter / UI.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${DIR}/../.." && pwd)"
CACHE="${ROOT}/ThirdParty/OpenJDKMobile/cache"

export PATH="${CACHE}/autoconf-prefix/bin:${CACHE}/m4-prefix/bin:${PATH:-}"
if [[ -x "${CACHE}/jdk-26.0.2+10/Contents/Home/bin/java" ]]; then
  export BOOT_JDK_HOME="${CACHE}/jdk-26.0.2+10/Contents/Home"
  export JAVA_HOME="${BOOT_JDK_HOME}"
elif [[ -x "${CACHE}/jdk-24.0.2+12/Contents/Home/bin/java" ]]; then
  export BOOT_JDK_HOME="${CACHE}/jdk-24.0.2+12/Contents/Home"
  export JAVA_HOME="${BOOT_JDK_HOME}"
fi

"${DIR}/00-check-host-tools.sh" || true
# Soft-check: continue if only Boot JDK path needs BOOT_JDK_HOME (already set).

"${DIR}/01-fetch-sources.sh"
"${DIR}/03b-configure-macos-host.sh"
"${DIR}/04b-build-macos-host.sh"
"${DIR}/05b-stage-macos-host.sh"

echo
echo "Phase 1.5 OpenJDK Mobile (macOS host) staged under artifacts/openjdk-mobile/staged/"
