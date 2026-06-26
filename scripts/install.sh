#!/usr/bin/env bash
# Install Deepiri Wooven via curl:
#   curl -fsSL https://raw.githubusercontent.com/Team-Deepiri/deepiri-wooven/main/scripts/install.sh | bash
#
# Clones the repository (or uses DEEPIRI_WOOVEN_SRC), then runs ./install.sh.
set -euo pipefail

REPO="Team-Deepiri/deepiri-wooven"
REPO_URL="https://github.com/${REPO}.git"
BRANCH="${DEEPIRI_WOOVEN_BRANCH:-main}"
KEEP_DIR="${DEEPIRI_WOOVEN_KEEP_DIR:-0}"

usage() {
  cat <<'EOF'
Usage: install.sh [options] [-- install.sh options]

Options:
  -h, --help     Show this help
  --dry-run      Print actions without cloning or installing
  -- install.sh options are passed to the repo install.sh (e.g. --no-venv)

Environment:
  DEEPIRI_WOOVEN_SRC        Use an existing checkout instead of cloning
  DEEPIRI_WOOVEN_BRANCH     Git branch to clone (default: main)
  DEEPIRI_WOOVEN_KEEP_DIR   Set to 1 to keep the clone directory after install

Requires: git, python3 (3.10+)
Verify:   deepiri-wooven --version && deepiri-wooven service status
EOF
}

dry_run() { printf '==> %s\n' "$*"; }

DRY_RUN=0
INSTALL_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --)
      shift
      INSTALL_ARGS+=("$@")
      break
      ;;
    *)
      INSTALL_ARGS+=("$1")
      shift
      ;;
  esac
done

for cmd in git python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required." >&2
    exit 1
  fi
done

ROOT=""
CLEANUP=""

if [[ -n "${DEEPIRI_WOOVEN_SRC:-}" && -f "${DEEPIRI_WOOVEN_SRC}/install.sh" ]]; then
  ROOT="${DEEPIRI_WOOVEN_SRC}"
elif [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != bash ]] && [[ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install.sh" ]]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  ROOT="$(mktemp -d)"
  if [[ "$KEEP_DIR" != "1" ]]; then
    CLEANUP="$ROOT"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    dry_run "Would clone ${REPO_URL} (branch ${BRANCH}) to ${ROOT}"
    dry_run "Would run: ${ROOT}/install.sh ${INSTALL_ARGS[*]:-}"
    exit 0
  fi
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$ROOT"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  dry_run "Would run: ${ROOT}/install.sh ${INSTALL_ARGS[*]:-}"
  exit 0
fi

trap '[[ -n "$CLEANUP" ]] && rm -rf "$CLEANUP"' EXIT
exec bash "${ROOT}/install.sh" "${INSTALL_ARGS[@]}"
