#!/usr/bin/env bash
# preflight.sh — Check required tools, auth state, and workshop facts.
#
# Usage:
#   bash scripts/preflight.sh                    # check everything except agent CLI
#   bash scripts/preflight.sh --agent claude     # also verify a specific agent CLI
#   bash scripts/preflight.sh --agent codex
#   bash scripts/preflight.sh --agent gemini
#   bash scripts/preflight.sh --agent copilot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FACTS_FILE="$KIT_DIR/workshop-facts.yaml"
AGENT=""

for arg in "$@"; do
    case "$arg" in
        --agent) ;;                      # consumed by next iteration
        --agent=*) AGENT="${arg#--agent=}" ;;
        claude|codex|gemini|copilot) AGENT="$arg" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Handle "--agent <value>" (two-arg form)
for i in "$@"; do
    if [[ "$i" == "--agent" ]]; then
        NEXT=true
    elif [[ "${NEXT:-false}" == "true" ]]; then
        AGENT="$i"
        NEXT=false
    fi
done

FAIL=0

ok()   { echo "  OK      $*"; }
fail() { echo "  MISSING $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN    $*"; }

echo ""
echo "Preflight checks"
echo "========================================"

# ---------------------------------------------------------------------------
# Core tools
# ---------------------------------------------------------------------------

if command -v gh &>/dev/null; then
    ok "gh CLI: $(gh --version | head -1)"
else
    fail "gh (GitHub CLI) not found — install from https://cli.github.com/"
fi

if command -v git &>/dev/null; then
    ok "git: $(git --version)"
else
    fail "git not found"
fi

if command -v python3 &>/dev/null; then
    ok "python3: $(python3 --version)"
else
    fail "python3 not found — install from https://python.org"
fi

if python3 -c "import yaml" &>/dev/null 2>&1; then
    ok "PyYAML available"
else
    fail "PyYAML not installed — fix with: pip install pyyaml"
fi

# ---------------------------------------------------------------------------
# GitHub auth
# ---------------------------------------------------------------------------

if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        ok "gh authenticated as: $GH_USER"
    else
        fail "gh is not authenticated — run: gh auth login"
    fi
fi

# ---------------------------------------------------------------------------
# Agent CLI (optional, only checked when --agent is passed)
# ---------------------------------------------------------------------------

if [[ -n "$AGENT" ]]; then
    echo ""
    echo "Agent CLI check: $AGENT"
    case "$AGENT" in
        claude)
            if command -v claude &>/dev/null; then
                ok "claude found: $(claude --version 2>/dev/null | head -1 || echo 'version unknown')"
            else
                fail "claude not found — install with: npm install -g @anthropic-ai/claude-code"
            fi
            ;;
        codex)
            if command -v codex &>/dev/null; then
                ok "codex found: $(codex --version 2>/dev/null | head -1 || echo 'version unknown')"
            else
                fail "codex not found — install with: npm install -g @openai/codex"
            fi
            ;;
        gemini)
            if command -v gemini &>/dev/null; then
                ok "gemini found: $(gemini --version 2>/dev/null | head -1 || echo 'version unknown')"
            else
                fail "gemini not found — install with: npm install -g @google/gemini-cli"
            fi
            ;;
        copilot)
            if gh extension list 2>/dev/null | grep -q "copilot"; then
                ok "gh copilot extension installed"
            else
                fail "gh copilot not installed — run: gh extension install github/gh-copilot"
            fi
            ;;
        *)
            warn "Unknown agent '$AGENT' — skipping agent check"
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# workshop-facts.yaml exists and is valid
# ---------------------------------------------------------------------------

echo ""
if [[ -f "$FACTS_FILE" ]]; then
    ok "workshop-facts.yaml found"
else
    fail "workshop-facts.yaml not found"
    echo ""
    echo "  Copy an example to get started:"
    echo "    cp examples/lc-online.yaml workshop-facts.yaml"
    echo "    cp examples/swc-inperson.yaml workshop-facts.yaml"
    echo "    cp examples/dc-multiday.yaml workshop-facts.yaml"
    echo ""
fi

if [[ $FAIL -eq 0 ]] && [[ -f "$FACTS_FILE" ]]; then
    python3 "$SCRIPT_DIR/validate.py" "$FACTS_FILE"
    VALIDATE_EXIT=$?
    if [[ $VALIDATE_EXIT -ne 0 ]]; then
        FAIL=$((FAIL + 1))
    fi
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

echo "========================================"
if [[ $FAIL -eq 0 ]]; then
    echo "All preflight checks passed."
    echo ""
    exit 0
else
    echo "Preflight failed: $FAIL issue(s) above must be resolved before continuing."
    echo ""
    exit 1
fi
