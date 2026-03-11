#!/usr/bin/env bash
# bootstrap-repo.sh — Create or repair a Carpentries workshop repo.
#
# Modes:
#   bash scripts/bootstrap-repo.sh              # create (fresh repo)
#   bash scripts/bootstrap-repo.sh --repair     # repair existing repo
#   bash scripts/bootstrap-repo.sh --dry-run    # preview without changes
#   bash scripts/bootstrap-repo.sh --repair --dry-run
#
# Repair checks (run automatically when repo already exists):
#   - Local clone present; clones if missing
#   - Local default branch is gh-pages; switches if not
#   - Remote default branch is gh-pages; sets via API if not
#   - _includes/syllabus.html exists; creates and pushes if missing
#   - GitHub Pages is enabled on gh-pages; enables via API if not
#
# Reads: workshop-facts.yaml (must pass validate.py first)
# Requires: gh CLI (authenticated), git, python3, PyYAML

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FACTS_FILE="$KIT_DIR/workshop-facts.yaml"
DRY_RUN=false
REPAIR=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --repair)  REPAIR=true ;;
        *) echo "Unknown argument: $arg  (try --dry-run or --repair)"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

run() {
    # run CMD... — executes or prints in dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

step() { echo ""; echo "Step $1: $2"; }
ok()   { echo "  OK      $*"; }
warn() { echo "  WARN    $*"; }
info() { echo "  -->     $*"; }

# ---------------------------------------------------------------------------
# Read facts from YAML
# ---------------------------------------------------------------------------

read_fact() {
    python3 - "$FACTS_FILE" "$1" <<'EOF'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
parts = sys.argv[2].split(".")
obj = data
for p in parts:
    if not isinstance(obj, dict) or p not in obj:
        print(""); sys.exit(0)
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
CLONE_DIR="$KIT_DIR/../$REPO_NAME"

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN MODE — no changes will be made"
    echo "========================================"
fi
echo "Bootstrap: $FULL_REPO"
echo "========================================"
echo "  Owner:     $OWNER"
echo "  Repo:      $REPO_NAME"
echo "  Title:     $TITLE"
echo "  Mode:      $MODE"
echo "  Clone to:  $CLONE_DIR"

# ---------------------------------------------------------------------------
# Detect existing repo
# ---------------------------------------------------------------------------

if gh repo view "$FULL_REPO" &>/dev/null 2>&1; then
    REPO_EXISTS=true
    info "Repository $FULL_REPO already exists — running repair checks"
    REPAIR=true
else
    REPO_EXISTS=false
fi

# ---------------------------------------------------------------------------
# Step 1: Create repo from template (fresh only)
# ---------------------------------------------------------------------------

step 1 "Create repo from Carpentries template"
if [[ "$REPO_EXISTS" == "true" ]]; then
    ok "Repo exists — skipping creation"
else
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] gh repo create $FULL_REPO --template carpentries/workshop-template --public"
    else
        gh repo create "$FULL_REPO" \
            --template carpentries/workshop-template \
            --public \
            --description "$TITLE"
        ok "Created: https://github.com/$FULL_REPO"
        # Give GitHub a moment to initialize the template
        sleep 3
    fi
fi

# ---------------------------------------------------------------------------
# Step 2: Enforce gh-pages as remote default branch
# ---------------------------------------------------------------------------

step 2 "Enforce gh-pages as remote default branch"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would check and set remote default branch to gh-pages"
else
    REMOTE_DEFAULT=$(gh repo view "$FULL_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "unknown")
    if [[ "$REMOTE_DEFAULT" == "gh-pages" ]]; then
        ok "Remote default branch: gh-pages"
    else
        info "Remote default branch is '$REMOTE_DEFAULT' — setting to gh-pages"
        # Ensure gh-pages exists on remote (template should have it; create if missing)
        if ! gh api "repos/$FULL_REPO/branches/gh-pages" &>/dev/null 2>&1; then
            warn "gh-pages branch not found on remote."
            warn "This may mean the template did not initialize correctly."
            warn "Check https://github.com/$FULL_REPO/branches and create gh-pages manually if needed."
        else
            gh api \
                --method PATCH \
                -H "Accept: application/vnd.github+json" \
                "/repos/$FULL_REPO" \
                -f "default_branch=gh-pages" &>/dev/null \
                && ok "Remote default branch set to gh-pages" \
                || warn "Could not set default branch via API — set manually in repo Settings → General"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Step 3: Clone (or verify local clone)
# ---------------------------------------------------------------------------

step 3 "Local clone"
if [[ -d "$CLONE_DIR/.git" ]]; then
    ok "Already cloned at $CLONE_DIR"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would clone $FULL_REPO to $CLONE_DIR"
else
    git clone "https://github.com/$FULL_REPO.git" "$CLONE_DIR"
    ok "Cloned to $CLONE_DIR"
fi

# ---------------------------------------------------------------------------
# Step 4: Enforce local gh-pages branch
# ---------------------------------------------------------------------------

step 4 "Enforce local gh-pages branch"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would verify local branch is gh-pages and switch if not"
elif [[ -d "$CLONE_DIR/.git" ]]; then
    LOCAL_BRANCH=$(git -C "$CLONE_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [[ "$LOCAL_BRANCH" == "gh-pages" ]]; then
        ok "Local branch: gh-pages"
    else
        info "Local branch is '$LOCAL_BRANCH' — switching to gh-pages"
        if git -C "$CLONE_DIR" show-ref --verify --quiet "refs/heads/gh-pages"; then
            git -C "$CLONE_DIR" checkout gh-pages
            ok "Switched to gh-pages"
        elif git -C "$CLONE_DIR" show-ref --verify --quiet "refs/remotes/origin/gh-pages"; then
            git -C "$CLONE_DIR" checkout -b gh-pages origin/gh-pages
            ok "Checked out gh-pages from remote"
        else
            warn "gh-pages branch not found locally or on remote."
            warn "This repo may not have been created from the Carpentries template."
            warn "See: https://github.com/carpentries/workshop-template"
        fi
    fi
else
    warn "No local clone found — skipping branch check (clone failed or dry-run)"
fi

# ---------------------------------------------------------------------------
# Step 5: Create _includes/syllabus.html (prevents known build error)
# ---------------------------------------------------------------------------

step 5 "Ensure _includes/syllabus.html exists"
SYLLABUS_PATH="$CLONE_DIR/_includes/syllabus.html"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would create $SYLLABUS_PATH if missing"
elif [[ -f "$SYLLABUS_PATH" ]]; then
    ok "_includes/syllabus.html already exists"
elif [[ -d "$CLONE_DIR/.git" ]]; then
    touch "$SYLLABUS_PATH"
    git -C "$CLONE_DIR" add "_includes/syllabus.html"
    git -C "$CLONE_DIR" commit -m "Add empty syllabus.html to prevent build error"
    git -C "$CLONE_DIR" push origin gh-pages
    ok "Created and pushed _includes/syllabus.html"
else
    warn "No local clone — cannot create syllabus.html (re-run after clone succeeds)"
fi

# ---------------------------------------------------------------------------
# Step 6: Enable / verify GitHub Pages
# ---------------------------------------------------------------------------

step 6 "Enable GitHub Pages on gh-pages branch"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would check Pages status and enable if needed"
else
    PAGES_STATUS=$(gh api "repos/$FULL_REPO/pages" --jq '.status' 2>/dev/null || echo "not_found")
    if [[ "$PAGES_STATUS" == "built" || "$PAGES_STATUS" == "building" ]]; then
        ok "GitHub Pages: $PAGES_STATUS"
        info "URL: https://$OWNER.github.io/$REPO_NAME/"
    elif [[ "$PAGES_STATUS" == "not_found" || "$PAGES_STATUS" == "null" ]]; then
        info "Pages not yet enabled — enabling now"
        gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            "/repos/$FULL_REPO/pages" \
            -f "source[branch]=gh-pages" \
            -f "source[path]=/" \
            &>/dev/null \
            && ok "GitHub Pages enabled. First build takes 2–5 minutes." \
            || warn "Pages API call failed — enable manually: repo Settings → Pages → Branch: gh-pages"
        info "URL: https://$OWNER.github.io/$REPO_NAME/"
    else
        warn "Pages status: $PAGES_STATUS — check repo Settings → Pages if the site isn't building"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
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
fi
echo ""
