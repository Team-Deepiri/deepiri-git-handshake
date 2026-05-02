#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ -x .venv/bin/python ]]; then PY=.venv/bin/python
else PY=python3
fi
$PY -c "from deepiri_git_handshake.transport import clone_url; print(clone_url('github.com','x','y','ssh'))"
$PY -c "from deepiri_git_handshake import __version__; print('deepiri-git-handshake', __version__)"
