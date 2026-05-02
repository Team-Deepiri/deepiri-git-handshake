"""Textual TUI for Deepiri Git Handshake."""

from __future__ import annotations

import subprocess
from pathlib import Path

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Footer, Header, Input, Label, RichLog, Select, Static

from deepiri_git_handshake.credentials import setup_for_transport
from deepiri_git_handshake.transport import clone_url, detect_transport


def _normalize_target(raw: str) -> str:
    s = raw.strip()
    if not s or s == ".":
        return "."
    return str(Path(s).expanduser())


class GitHandshakeApp(App[None]):
    CSS = """
    Screen { align: center middle; }
    #main { width: 88; max-width: 100%; height: auto; border: heavy $primary; padding: 1 2; }
    #fields Input { margin-bottom: 1; }
    #log { height: 12; min-height: 8; border: round $boost; margin-top: 1; }
    #hint { margin-top: 1; color: $text-muted; }
    #actions { margin-top: 1; height: auto; }
    """

    BINDINGS = [("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Container(id="main"):
            yield Static("[b]Deepiri Git Handshake[/b] — owner, repo, directory", id="title")
            with Vertical(id="fields"):
                yield Label("Forge host")
                yield Input(placeholder="github.com", id="host", value="github.com")
                yield Label("Transport")
                yield Select(
                    (
                        ("Auto (detect)", "auto"),
                        ("SSH (git@host:…)", "ssh"),
                        ("HTTPS", "https"),
                    ),
                    id="transport",
                    allow_blank=False,
                    value="auto",
                )
                yield Label("Owner (user or organization)")
                yield Input(placeholder="octocat", id="owner")
                yield Label("Repository name")
                yield Input(placeholder="Hello-World", id="repo")
                yield Label("Target directory (empty or . = current directory)")
                yield Input(placeholder=".", id="target")
            yield Static(
                "Auto checks SSH to git@host first, then ~/.ssh keys; otherwise HTTPS.",
                id="hint",
            )
            yield RichLog(id="log", highlight=True, markup=True)
            with Horizontal(id="actions"):
                yield Button("Clone", variant="primary", id="clone_btn")
                yield Button("Setup credentials", id="cred_btn")
                yield Button("Detect transport now", id="detect_btn")
        yield Footer()

    def on_mount(self) -> None:
        log = self.query_one("#log", RichLog)
        log.write(
            "[dim]Ready. Run [b]Setup credentials[/] once per machine, then clone.[/]"
        )

    def action_quit(self) -> None:
        self.exit()

    @on(Button.Pressed, "#detect_btn")
    def detect_now(self) -> None:
        host = self.query_one("#host", Input).value.strip() or "github.com"
        chosen = detect_transport(host)
        sel = self.query_one("#transport", Select)
        sel.value = "ssh" if chosen == "ssh" else "https"
        log = self.query_one("#log", RichLog)
        log.write(f"[cyan]Detected preferred transport:[/] [b]{chosen}[/] (for {host})")

    @on(Button.Pressed, "#cred_btn")
    def run_credentials(self) -> None:
        log = self.query_one("#log", RichLog)
        host = self.query_one("#host", Input).value.strip() or "github.com"
        transport = self._resolved_transport(host)
        log.write(f"[yellow]Credential setup[/] ({transport.upper()} @ {host})")
        for line in setup_for_transport(transport, host):
            log.write(line)
        log.write("[dim]Credential pass complete.[/]")

    def _resolved_transport(self, host: str) -> str:
        sel = self.query_one("#transport", Select).value
        if sel == "auto":
            return detect_transport(host)
        assert isinstance(sel, str)
        return sel

    @on(Button.Pressed, "#clone_btn")
    def run_clone(self) -> None:
        log = self.query_one("#log", RichLog)
        host = self.query_one("#host", Input).value.strip() or "github.com"
        owner = self.query_one("#owner", Input).value.strip()
        repo = self.query_one("#repo", Input).value.strip()
        target = _normalize_target(self.query_one("#target", Input).value)

        if not owner or not repo:
            log.write("[red]Owner and repository name are required.[/]")
            self.bell()
            return

        transport = self._resolved_transport(host)
        url = clone_url(host, owner, repo, transport)
        log.write(f"[green]Using[/] {transport.upper()} [dim]{url}[/]")

        if target == ".":
            try:
                if any(Path(".").iterdir()):
                    log.write(
                        "[red]Current directory is not empty. "
                        "Use an empty folder or a new subdirectory name.[/]"
                    )
                    self.bell()
                    return
            except OSError as e:
                log.write(f"[red]Cannot read current directory: {e}[/]")
                return

        try:
            proc = subprocess.run(
                ["git", "clone", url, target],
                capture_output=True,
                text=True,
                timeout=600,
            )
        except FileNotFoundError:
            log.write("[red]git not found on PATH.[/]")
            self.bell()
            return
        except subprocess.TimeoutExpired:
            log.write("[red]git clone timed out.[/]")
            self.bell()
            return

        if proc.stdout:
            log.write(proc.stdout.rstrip())
        if proc.stderr:
            log.write(proc.stderr.rstrip())
        if proc.returncode == 0:
            log.write(f"[bold green]Done.[/] Cloned into [cyan]{target}[/]")
            log.write("[yellow]Running credential helper pass for this transport…[/]")
            for line in setup_for_transport(transport, host):
                log.write(line)
            self._post_success_tips(log, transport)
        else:
            log.write(f"[red]git clone failed (exit {proc.returncode}).[/]")
            self.bell()

    def _post_success_tips(self, log: RichLog, transport: str) -> None:
        if transport == "https":
            log.write(
                "[dim]HTTPS: for private repos, use `gh auth setup-git` or your OS credential manager.[/]"
            )
        else:
            log.write(
                "[dim]SSH: ensure your public key is registered on the forge; "
                "`ssh -T git@github.com` to verify.[/]"
            )
