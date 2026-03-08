# Claude Code Sandboxing

Two complementary sandboxing approaches for running `claude --dangerously-skip-permissions` safely.

## Quick Start

```bash
# Initial setup (installs cco + builds Podman image)
chmod +x setup.sh && ./setup.sh

# cco — fast, Seatbelt-based
cco "your prompt"

# Podman — full filesystem isolation
./scripts/run-claude-podman.sh "your prompt"
```

---

## Approaches

### cco (Claude Condom)
Uses macOS Seatbelt (`sandbox-exec`) to restrict filesystem and network access at the OS level. Near-zero overhead, runs locally.

- Source: https://github.com/nikvdp/cco
- Requires: macOS with `sandbox-exec` (standard on all modern macOS)

### Podman Container
Alpine-based container with Node.js + `@anthropic-ai/claude-code`. Full filesystem isolation — Claude can only see the mounted project directory and `~/.claude`.

- Image: `claude-sandbox:latest` (built from `Containerfile`)
- Wrapper: `scripts/run-claude-podman.sh`

---

## Comparison

| Feature                  | cco (Seatbelt)     | Podman Container     |
|--------------------------|-------------------|----------------------|
| Filesystem isolation     | Partial (policy)  | Full                 |
| Network isolation        | Partial           | Optional (`--none`)  |
| Overhead                 | Minimal           | ~1-2s startup        |
| Session continuity       | Yes               | Yes (same-path mount)|
| Requires Podman running  | No                | Yes                  |
| Air-gapped mode          | No                | Yes (`--no-network`) |

---

## Podman Wrapper Usage

```bash
./scripts/run-claude-podman.sh [OPTIONS] [CLAUDE_ARGS...]

Options:
  --no-network    Disable all network access
  --rebuild       Rebuild the container image before running
  -h, --help      Show help

Examples:
  ./scripts/run-claude-podman.sh "what files are in the current directory?"
  ./scripts/run-claude-podman.sh --no-network "refactor this function"
  ./scripts/run-claude-podman.sh --rebuild
```

### Mount Strategy
| Host path          | Container path                  | Access |
|--------------------|---------------------------------|--------|
| `$PROJECT_ROOT`    | `$PROJECT_ROOT` (same path)     | rw     |
| `~/.claude`        | `/home/claudeuser/.claude`      | rw     |
| `~/.claude.json`   | `/home/claudeuser/.claude.json` | rw     |

The project directory is mounted at the **same absolute path** so Claude's session history (keyed by path in `~/.claude/projects/`) remains valid across container and host runs.

`~/.claude.json` is mounted read-write because Claude periodically refreshes OAuth tokens — a read-only mount would silently break authentication.

---

## Setup Script

```bash
./setup.sh              # Install everything
./setup.sh --cco-only   # Only install/update cco
./setup.sh --podman-only  # Only build Podman image
```

---

## Maintenance

### Update claude-code (Podman)
```bash
./scripts/run-claude-podman.sh --rebuild
```
Or rebuild directly:
```bash
podman build --no-cache -t claude-sandbox:latest -f Containerfile .
```

### Update cco
```bash
curl -fsSL https://raw.githubusercontent.com/nikvdp/cco/master/install.sh | bash
```

### Check Podman machine status
```bash
podman machine list
podman machine start   # if stopped
```

---

## Troubleshooting

### `podman: command not found`
Install Podman Desktop: https://podman-desktop.io

### `Error: no machine found` / machine not running
```bash
podman machine init   # first time only
podman machine start
```

### Permission denied on mounted files
The container uses UID 501 (`claudeuser`) with `--userns=keep-id`, which maps to your macOS UID. Files written by Claude inside the container will be owned by your user. If you see permission errors, verify your macOS user UID:
```bash
id -u   # should be 501 on a standard single-user Mac
```

### Auth broken inside container
Ensure `~/.claude.json` exists and is writable:
```bash
ls -la ~/.claude.json
touch ~/.claude.json
```

### cco not found after install
```bash
# cco installs to ~/.local/bin by default — ensure it's in your PATH:
export PATH="$HOME/.local/bin:$PATH"
# Add to ~/.zshrc or ~/.bashrc for persistence
```

### Verify filesystem isolation
```bash
# This should fail (or show nothing) — Desktop is not mounted in the container
./scripts/run-claude-podman.sh "list what's in /Users/matthewbasson/Desktop"
```
