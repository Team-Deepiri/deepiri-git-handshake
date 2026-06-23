# deepiri-wooven

TUI and CLI tool to **clone Git repos by owner/name**, pick **SSH or HTTPS** (with sensible defaults), and manage a small **credential vault**: per-host profiles, **HTTPS personal access tokens (PATs) in the OS keyring**, and a **`git-credential-wooven`** helper so plain `git` can authenticate over HTTPS without pasting tokens every time.

Licensed under **Apache-2.0** (see `LICENSE` and `NOTICE`).

## Requirements

- Python **3.10+**
- `git` on your `PATH`
- For HTTPS via PAT: a working **keyring** backend on your OS (most desktops have one; minimal Linux images may need extra packages—see [keyring](https://pypi.org/project/keyring/) docs).

## Install

One-line install (recommended):

```bash
git clone https://github.com/Team-Deepiri/deepiri-wooven.git
cd deepiri-wooven
./install.sh
source ~/.config/deepiri-wooven/path.sh
```

`./install.sh` creates a venv, installs the package, registers `git-credential-wooven`, installs a **git shim** on `~/.local/bin/git` (prepended via `path.sh`) that intercepts `git clone` and auto-picks **SSH or HTTPS**, and enables a **background service**:

| Platform | Service |
|----------|---------|
| Linux | systemd user unit `deepiri-wooven.service` |
| WSL | same systemd user unit |
| macOS | launchd agent `com.deepiri.wooven` |
| Windows | Scheduled task `DeepiriWooven` at logon |

When you clone, transport is chosen from your saved profile, **last-used transport** for that host, or a **one-time prompt** if both SSH and HTTPS look available. Plain `git clone owner/repo` defaults to `github.com`.

Manual install:

```bash
cd deepiri-wooven
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e .
deepiri-wooven service install
```

Entry points:

| Command | Purpose |
|--------|---------|
| `deepiri-wooven` | TUI + `cred` + `service` subcommands |
| `wooven` | Short alias for `deepiri-wooven` |
| `deepiri-wooven-git` | Git shim (normally via `~/.local/bin/git`) |
| `git-credential-wooven` | Git credential helper (normally invoked by git, not by hand) |

Service management:

```bash
deepiri-wooven service status
deepiri-wooven service start
deepiri-wooven service stop
deepiri-wooven service uninstall
```

Check the version:

```bash
wooven --version
```

## TUI (`wooven`)

Run with no arguments:

```bash
wooven
```

Two tabs:

### Clone

1. Set **Forge host** (default `github.com`).
2. Choose **Transport**: *Auto* uses your saved **Vault** preference for that host when it is `ssh` or `https`; otherwise it probes the machine (SSH to `git@host`, then keys, then HTTPS).
3. Enter **Owner** (user or org) and **Repository** name.
4. **Target directory**: leave empty or `.` to clone into the **current directory** (must be empty).
5. **Setup credentials** — runs the same checks as the Vault “setup” flow for the current transport.
6. **Clone** — runs `git clone` and then a short credential pass.

### Vault (credential manager)

1. **Forge host** — same idea as on the Clone tab.
2. **Preferred transport** — stored in your profile (`auto` / `ssh` / `https`). Clone *Auto* respects `ssh` or `https` when set.
3. **SSH private key path** — optional; used for agent loading hints and for **Apply SSH config**.
4. **HTTPS username** — optional; default for git over HTTPS is often `git`; use your username if your host expects it.
5. **HTTPS PAT** — paste a token and click **Store PAT**; it is stored in the **OS keyring**, not in the project files.
6. **Register git helper** — adds `wooven` to `credential.helper` globally so `git` can call `git-credential-wooven` for HTTPS.
7. **Apply SSH config** — writes a **marked** `Host` block to `~/.ssh/config` for this host (re-running replaces only that managed block).
8. **Run setup pass** — SSH or HTTPS diagnostics (agent, probe, `gh`, PAT status).
9. **List all** — prints profiles, PAT presence, and current `credential.helper` values.

Quit the TUI with **q** or standard terminal exit.

## CLI (`wooven cred …`)

Non-interactive vault and setup commands:

```bash
# List profiles and git credential helpers
wooven cred list

# Summary for one host
wooven cred show --host github.com

# Merge-update a profile (only include flags you want to change)
wooven cred set --host github.com --transport ssh --ssh-identity ~/.ssh/id_ed25519
wooven cred set --host github.com --https-user myuser

# Store PAT from stdin (avoid putting the token in shell history)
printf '%s' "ghp_xxxxxxxx" | wooven cred pat --host github.com --store
wooven cred pat --host github.com --clear

# Register / unregister git-credential-wooven (helper name "wooven")
wooven cred helper
wooven cred helper --unregister

# Write managed ~/.ssh/config Host block
wooven cred ssh-config --host github.com --identity ~/.ssh/id_ed25519

# Run SSH or HTTPS setup messages (like the TUI)
wooven cred setup --host github.com --transport ssh
wooven cred setup --host github.com --transport https
```

## HTTPS flow (PAT + git)

1. Create a PAT on your forge (e.g. GitHub fine-grained or classic token).
2. `wooven cred set --host github.com --https-user YOUR_USERNAME` if needed.
3. Pipe the token into `wooven cred pat --host github.com --store`.
4. Run `wooven cred helper` so git’s global config includes `credential.helper = wooven`.
5. Clone or fetch over `https://…`; git invokes `git-credential-wooven`, which reads the PAT from the keyring.

If you use **GitHub CLI**, `gh auth login` plus `gh auth setup-git` remains a good alternative; this tool complements that for hosts or workflows where you want an explicit PAT in the vault.

## Where data is stored

| Data | Location |
|------|----------|
| Profiles (transport, paths, HTTPS username) | `$XDG_CONFIG_HOME/deepiri-wooven/profiles.json` (fallback: `~/.config/...`) |
| PATs | OS keyring under service `deepiri-wooven` |
| Managed SSH snippet | `~/.ssh/config` (between `deepiri-wooven begin/end` markers per host) |

## Troubleshooting

- **`NoKeyringError` when storing a PAT** — Your environment has no keyring backend (common on minimal Linux or some CI images). Install a backend (for example `keyrings.alt`, or your distro’s Secret Service / KWallet integration) per the [keyring documentation](https://pypi.org/project/keyring/).
- **`git-credential-wooven` not found** — Install the package so the `git-credential-wooven` script is on your `PATH`, or activate the same venv you used for `pip install -e .`.
- **WSL** — Use the same guidance as Linux; ensure a D-Bus secret service is available if you expect the freedesktop backend.

## Development

```bash
pip install -e '.[dev]'
pytest
```

Quick local check (imports + optional pytest):

```bash
./scripts/smoke.sh
```

## Unregistering the git helper

`wooven cred helper --unregister` removes the `wooven` helper by **rewriting** all global `credential.helper` entries: it unsets every value, then re-adds every helper **except** `wooven`. If you rely on a custom helper string, re-check `git config --global --get-all credential.helper` afterward.
