#!/usr/bin/env bash
# preflight.sh — Check that all required tools are available and the workshop facts are valid.
# Run by ./start-workshop, or directly: bash scripts/preflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FACTS_FILE="$KIT_DIR/workshop-facts.yaml"

PASS=0
FAIL=0

ok()   { echo "  OK      $*"; }
fail() { echo "  MISSING $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN    $*"; }

echo ""
echo "Preflight checks"
echo "========================================"

# --- Tool: gh CLI ---
if command -v gh &>/dev/null; then
    ok "gh CLI found: $(gh --version | head -1)"
else
    fail "gh (GitHub CLI) not found. Install from https://cli.github.com/"
fi

# --- Tool: git ---
if command -v git &>/dev/null; then
    ok "git found: $(git --version)"
else
    fail "git not found"
fi

# --- Tool: python3 ---
if command -v python3 &>/dev/null; then
    ok "python3 found: $(python3 --version)"
else
    fail "python3 not found"
fi

# --- Python: PyYAML ---
if python3 -c "import yaml" &>/dev/null 2>&1; then
    ok "PyYAML available"
else
    fail "PyYAML not installed. Fix with: pip install pyyaml"
fi

# --- gh auth ---
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
        ok "gh authenticated as: $GH_USER"
    else
        fail "gh is not authenticated. Run: gh auth login"
    fi
fi

# --- workshop-facts.yaml exists ---
if [[ -f "$FACTS_FILE" ]]; then
    ok "workshop-facts.yaml found"
else
    fail "workshop-facts.yaml not found at $FACTS_FILE"
    echo ""
    echo "  Copy an example to get started:"
    echo "    cp examples/lc-online.yaml workshop-facts.yaml"
    echo ""
fi

echo ""

# --- Validate facts (only if tools passed so far) ---
if [[ $FAIL -eq 0 ]] && [[ -f "$FACTS_FILE" ]]; then
    python3 "$SCRIPT_DIR/validate.py" "$FACTS_FILE"
    VALIDATE_EXIT=$?
    if [[ $VALIDATE_EXIT -ne 0 ]]; then
        FAIL=$((FAIL + 1))
    fi
fi

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
