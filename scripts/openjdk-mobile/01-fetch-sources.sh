#!/usr/bin/env bash
# 01 — Fetch / update openjdk/mobile sources (Fase 0A).
# Outside App Target. Does not configure, build, or link.

set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ojdk_require_cmd git
ojdk_ensure_dirs

REF="${OPENJDK_MOBILE_REF}"
URL="${OPENJDK_MOBILE_GIT_URL}"

if [[ -d "${OJDK_SRC_DIR}/.git" ]]; then
  ojdk_log "Updating existing clone at ${OJDK_SRC_DIR}"
  git -C "${OJDK_SRC_DIR}" remote set-url origin "${URL}"
  git -C "${OJDK_SRC_DIR}" fetch --tags origin
  git -C "${OJDK_SRC_DIR}" checkout "${REF}"
  # If REF is a branch name, fast-forward; if SHA, checkout is enough.
  if git -C "${OJDK_SRC_DIR}" show-ref --verify --quiet "refs/remotes/origin/${REF}"; then
    git -C "${OJDK_SRC_DIR}" merge --ff-only "origin/${REF}" || true
  fi
else
  ojdk_log "Cloning ${URL} (ref ${REF}) → ${OJDK_SRC_DIR}"
  # Shallow clone of a branch is fine for exploration; for a SHA use full fetch depth.
  if [[ "${REF}" =~ ^[0-9a-fA-F]{40}$ ]]; then
    git clone "${URL}" "${OJDK_SRC_DIR}"
    git -C "${OJDK_SRC_DIR}" checkout "${REF}"
  else
    git clone --branch "${REF}" --single-branch "${URL}" "${OJDK_SRC_DIR}" \
      || git clone "${URL}" "${OJDK_SRC_DIR}"
    git -C "${OJDK_SRC_DIR}" checkout "${REF}"
  fi
fi

COMMIT="$(git -C "${OJDK_SRC_DIR}" rev-parse HEAD)"
ojdk_log "Checked out commit ${COMMIT}"
echo "${COMMIT}" > "${OJDK_OUT_DIR}/last-source-commit.txt"

if [[ "${REF}" == "master" || "${REF}" == "main" ]]; then
  ojdk_warn "Pin this SHA in ThirdParty/OpenJDKMobile/versions.env:"
  echo "  OPENJDK_MOBILE_REF=\"${COMMIT}\""
fi

ojdk_log "Sources ready."
