#!/usr/bin/env bash
# Orchestrator — full OpenJDK Mobile device static-libs pipeline (Fase 0A).
# Does not modify Xcode, FreeJ2ME, Bridge, Host, Adapter, Library, or UI.

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

"${DIR}/00-check-host-tools.sh"
"${DIR}/01-fetch-sources.sh"
"${DIR}/02-fetch-support.sh"
"${DIR}/03-configure-ios-device.sh"
"${DIR}/04-build-static-libs.sh"
"${DIR}/05-stage-artifacts.sh"
"${DIR}/06-verify-artifacts.sh"

echo
echo "Fase 0A pipeline complete: artifacts staged under artifacts/openjdk-mobile/staged/"
echo "App Target was NOT modified. JVM is NOT linked."
