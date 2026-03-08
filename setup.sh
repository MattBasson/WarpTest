#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="claude-sandbox:latest"
SETUP_CCO=true
SETUP_PODMAN=true

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Set up Claude Code sandboxing tools (cco and/or Podman container).

Options:
  --cco-only      Only install/update cco (skip Podman setup)
  --podman-only   Only set up Podman container (skip cco)
  -h, --help      Show this help message
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cco-only)
            SETUP_PODMAN=false
            shift
            ;;
        --podman-only)
            SETUP_CCO=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ── cco setup ────────────────────────────────────────────────────────────────
if $SETUP_CCO; then
    echo "==> Setting up cco (Claude Condom / macOS Seatbelt)..."

    if ! command -v sandbox-exec &>/dev/null; then
        echo "  WARNING: sandbox-exec not found. cco requires macOS with Seatbelt support."
        echo "  Skipping cco installation."
    else
        echo "  Installing/updating cco..."
        curl -fsSL https://raw.githubusercontent.com/nikvdp/cco/master/install.sh | bash
        echo "  cco installed successfully."
    fi
fi

# ── Podman setup ──────────────────────────────────────────────────────────────
if $SETUP_PODMAN; then
    echo "==> Setting up Podman container..."

    if ! command -v podman &>/dev/null; then
        echo "  ERROR: podman not found. Install Podman Desktop from https://podman-desktop.io"
        exit 1
    fi

    # Ensure Podman machine is running
    if ! podman machine list --format '{{.Running}}' 2>/dev/null | grep -q true; then
        echo "  Starting Podman machine..."
        podman machine start 2>/dev/null || {
            echo "  No machine found — initializing a new one..."
            podman machine init
            podman machine start
        }
    else
        echo "  Podman machine is already running."
    fi

    # Build the image
    echo "  Building $IMAGE (this may take a few minutes)..."
    podman build -t "$IMAGE" -f "$SCRIPT_DIR/Containerfile" "$SCRIPT_DIR"
    echo "  Image built successfully."

    # Make wrapper executable
    chmod +x "$SCRIPT_DIR/scripts/run-claude-podman.sh"
    echo "  Wrapper script is ready: $SCRIPT_DIR/scripts/run-claude-podman.sh"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================================================"
echo "  Claude Code Sandboxing Setup Complete"
echo "======================================================================"
echo ""
if $SETUP_CCO; then
    echo "  cco (Seatbelt-based, fast):"
    echo "    cco \"your prompt\""
    echo ""
fi
if $SETUP_PODMAN; then
    echo "  Podman container (full filesystem isolation):"
    echo "    ./scripts/run-claude-podman.sh \"your prompt\""
    echo "    ./scripts/run-claude-podman.sh --no-network \"your prompt\""
    echo "    ./scripts/run-claude-podman.sh --rebuild   # after claude-code update"
    echo ""
fi
echo "  See CLAUDE.md for full documentation."
echo "======================================================================"
