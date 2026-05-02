"""CLI entry for Deepiri Git Handshake."""

from __future__ import annotations

import argparse
import sys

from deepiri_git_handshake import __version__
from deepiri_git_handshake.tui import GitHandshakeApp


def main() -> None:
    parser = argparse.ArgumentParser(
        description="TUI: pick SSH/HTTPS (or auto), enter owner/repo, clone to a directory.",
    )
    parser.add_argument("--version", action="store_true", help="Print version and exit")
    args = parser.parse_args()
    if args.version:
        print(__version__)
        sys.exit(0)
    GitHandshakeApp().run()


if __name__ == "__main__":
    main()
