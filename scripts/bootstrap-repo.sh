#!/usr/bin/env bash
# bootstrap-repo.sh — Create a Carpentries workshop repo from the official template.
#
# Usage:
#   bash scripts/bootstrap-repo.sh              # live run
#   bash scripts/bootstrap-repo.sh --dry-run    # print what would happen, make no changes
#
# Reads: workshop-facts.yaml (must pass validate.py first)
# Requires: gh CLI (authenticated), git, python3, PyYAML

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FACTS_FILE="$KIT_DIR/workshop-facts.yaml"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "DRY-RUN MODE — no changes will be made"
    echo "========================================"
fi

# ---------------------------------------------------------------------------
# Read facts from YAML via Python
# ---------------------------------------------------------------------------

read_fact() {
    # read_fact "key.subkey" → prints value or exits with error
    local path="$1"
    python3 - "$FACTS_FILE" "$path" <<'EOF'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
parts = sys.argv[2].split(".")
obj = data
for p in parts:
    if not isinstance(obj, dict) or p not in obj:
        print("")
        sys.exit(0)
    obj = obj[p]
print("" if obj is None else str(obj))
EOF
}

OWNER=$(read_fact "github.owner")
REPO_NAME=$(read_fact "github.repo_name")
TITLE=$(read_fact "workshop.title")
MODE=$(read_fact "event.mode")

if [[ -z "$OWNER" || -z "$REPO_NAME" ]]; then
    echo "ERROR: github.owner and github.repo_name must be set in workshop-facts.yaml"
    exit 1
fi

FULL_REPO="$OWNER/$REPO_NAME"
CLONE_DIR="$KIT_DIR/../$REPO_NAME"   # sibling of this kit directory

echo ""
echo "Bootstrap: $FULL_REPO"
echo "========================================"
echo "  Owner:     $OWNER"
echo "  Repo:      $REPO_NAME"
echo "  Title:     $TITLE"
echo "  Mode:      $MODE"
echo "  Clone to:  $CLONE_DIR"
echo ""

# ---------------------------------------------------------------------------
# Check for existing repo
# ---------------------------------------------------------------------------

if gh repo view "$FULL_REPO" &>/dev/null 2>&1; then
    echo "WARN: Repository $FULL_REPO already exists on GitHub."
    echo "      Bootstrap will skip repo creation and Pages setup."
    echo "      If the repo is in a partial state, continue with the agent session."
    REPO_EXISTS=true
else
    REPO_EXISTS=false
fi

# ---------------------------------------------------------------------------
# Step 1: Create repo from template
# ---------------------------------------------------------------------------

if [[ "$REPO_EXISTS" == "false" ]]; then
    echo "Step 1: Create repo from Carpentries template"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would run:"
        echo "    gh repo create $FULL_REPO --template carpentries/workshop-template --public"
    else
        gh repo create "$FULL_REPO" \
            --template carpentries/workshop-template \
            --public \
            --description "$TITLE"
        echo "  Created: https://github.com/$FULL_REPO"
    fi
else
    echo "Step 1: Skipped — repo already exists"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 2: Clone
# ---------------------------------------------------------------------------

echo "Step 2: Clone repo"
if [[ -d "$CLONE_DIR/.git" ]]; then
    echo "  Already cloned at $CLONE_DIR — skipping"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would clone $FULL_REPO to $CLONE_DIR"
else
    git clone "https://github.com/$FULL_REPO.git" "$CLONE_DIR"
    echo "  Cloned to $CLONE_DIR"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 3: Confirm gh-pages branch
# ---------------------------------------------------------------------------

echo "Step 3: Confirm gh-pages branch"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would verify default branch is gh-pages"
else
    DEFAULT_BRANCH=$(gh repo view "$FULL_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "unknown")
    if [[ "$DEFAULT_BRANCH" == "gh-pages" ]]; then
        echo "  Default branch: gh-pages ✓"
    else
        echo "  WARN: Default branch is '$DEFAULT_BRANCH', not 'gh-pages'."
        echo "        You may need to update this in GitHub repo settings."
    fi
fi
echo ""

# ---------------------------------------------------------------------------
# Step 4: Create empty syllabus.html (prevents known build error)
# ---------------------------------------------------------------------------

echo "Step 4: Create _includes/syllabus.html (prevents build error)"
SYLLABUS_PATH="$CLONE_DIR/_includes/syllabus.html"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would create empty file at _includes/syllabus.html"
elif [[ -f "$SYLLABUS_PATH" ]]; then
    echo "  Already exists — skipping"
else
    touch "$SYLLABUS_PATH"
    cd "$CLONE_DIR"
    git add "_includes/syllabus.html"
    git commit -m "Add empty syllabus.html to prevent build error"
    git push origin gh-pages
    echo "  Created and pushed _includes/syllabus.html"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 5: Enable GitHub Pages
# ---------------------------------------------------------------------------

echo "Step 5: Enable GitHub Pages (gh-pages branch)"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would enable Pages via GitHub API"
elif [[ "$REPO_EXISTS" == "true" ]]; then
    echo "  Skipped — repo already existed (Pages may already be enabled)"
else
    # GitHub API to enable Pages
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/$FULL_REPO/pages" \
        -f "source[branch]=gh-pages" \
        -f "source[path]=/" \
        &>/dev/null || echo "  WARN: Pages API call failed — enable manually in repo Settings → Pages"
    echo "  GitHub Pages enabled. First build takes 2–5 minutes."
    echo "  URL: https://$OWNER.github.io/$REPO_NAME/"
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "========================================"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Dry run complete. Re-run without --dry-run to apply changes."
else
    echo "Bootstrap complete."
    echo ""
    echo "  Repo:    https://github.com/$FULL_REPO"
    echo "  Site:    https://$OWNER.github.io/$REPO_NAME/"
    echo "  Cloned:  $CLONE_DIR"
    echo ""
    echo "Next: start your agent session from this kit directory."
    echo "  The agent will configure _config.yml, index.md, and the schedule."
fi
echo ""
