#!/usr/bin/env bash
# Install Deepiri Wooven as a user-level library with git clone interception.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required (3.10+)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required on PATH." >&2
  exit 1
fi

PY=python3
VENV="$ROOT/.venv"
USE_VENV=1
INSTALL_MODE="user"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --system)
      INSTALL_MODE="system"
      USE_VENV=0
      shift
      ;;
    --no-venv)
      USE_VENV=0
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: ./install.sh [options]

Installs deepiri-wooven, registers git-credential-wooven, installs a git
shim for clone transport auto-switching, and enables the platform background
service (systemd on Linux/WSL, launchd on macOS, Task Scheduler on Windows).

Options:
  --system   pip install system-wide (requires appropriate permissions)
  --no-venv  install with pip --user instead of a project .venv
  -h, --help show this help
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$USE_VENV" -eq 1 ]]; then
  log "Creating virtualenv at $VENV"
  "$PY" -m venv "$VENV"
  PY="$VENV/bin/python"
  PIP="$VENV/bin/pip"
else
  PIP="pip3"
fi

log "Installing package"
if [[ "$INSTALL_MODE" == "system" ]]; then
  "$PIP" install "$ROOT"
elif [[ "$USE_VENV" -eq 1 ]]; then
  "$PIP" install -e "$ROOT"
else
  "$PIP" install --user "$ROOT"
fi

LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "$LOCAL_BIN"

if [[ "$USE_VENV" -eq 1 ]]; then
  for cmd in deepiri-wooven wooven deepiri-wooven-git git-credential-wooven deepiri-wooven-daemon; do
    if [[ -x "$VENV/bin/$cmd" ]]; then
      ln -sf "$VENV/bin/$cmd" "$LOCAL_BIN/$cmd"
    fi
  done
  export PATH="$LOCAL_BIN:$VENV/bin:${PATH}"
else
  case ":${PATH}:" in
    *":${LOCAL_BIN}:"*) ;;
    *) export PATH="${LOCAL_BIN}:${PATH}" ;;
  esac
fi

if ! command -v deepiri-wooven >/dev/null 2>&1; then
  warn "deepiri-wooven not found on PATH; add ${LOCAL_BIN} to your shell profile."
fi

log "Running deepiri-wooven service install"
if command -v deepiri-wooven >/dev/null 2>&1; then
  deepiri-wooven service install
else
  "$PY" -c "from deepiri_wooven.service import run_install; raise SystemExit(run_install())"
fi

PROFILE_SNIPPET="${HOME}/.config/deepiri-wooven/path.sh"
mkdir -p "$(dirname "$PROFILE_SNIPPET")"
cat >"$PROFILE_SNIPPET" <<EOF
# Added by deepiri-wooven install.sh
export PATH="${LOCAL_BIN}:\${PATH}"
EOF

log "Installed. Ensure your shell loads: source ${PROFILE_SNIPPET}"
log "Verify: deepiri-wooven --version && deepiri-wooven service status"
