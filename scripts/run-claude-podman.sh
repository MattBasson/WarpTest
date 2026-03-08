#!/usr/bin/env bash
set -euo pipefail

IMAGE="claude-sandbox:latest"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NETWORK="bridge"
REBUILD=false
CLAUDE_ARGS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [CLAUDE_ARGS...]

Run Claude Code in an isolated Podman container.

Options:
  --no-network    Disable network access (air-gapped mode)
  --rebuild       Rebuild the container image before running
  -h, --help      Show this help message

Any additional arguments are passed directly to claude.

Examples:
  $(basename "$0") "what files are in the current directory?"
  $(basename "$0") --no-network "refactor this function"
  $(basename "$0") --rebuild
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-network)
            NETWORK="none"
            shift
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            CLAUDE_ARGS+=("$1")
            shift
            ;;
    esac
done

# Rebuild image if requested or if it doesn't exist
if $REBUILD || ! podman image exists "$IMAGE" 2>/dev/null; then
    echo "Building $IMAGE..."
    podman build -t "$IMAGE" -f "$PROJECT_ROOT/Containerfile" "$PROJECT_ROOT"
fi

# Ensure ~/.claude and ~/.claude.json exist so mounts don't create directories
mkdir -p "$HOME/.claude"
touch "$HOME/.claude.json"

exec podman run --rm -it \
    --userns=keep-id \
    --cap-drop=ALL \
    --security-opt no-new-privileges \
    --tmpfs /tmp:rw,noexec,nosuid,size=256m \
    --network "$NETWORK" \
    -v "$PROJECT_ROOT:$PROJECT_ROOT:z" \
    -v "$HOME/.claude:/home/claudeuser/.claude:z" \
    -v "$HOME/.claude.json:/home/claudeuser/.claude.json:z" \
    -w "$PROJECT_ROOT" \
    "$IMAGE" \
    "${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}"
