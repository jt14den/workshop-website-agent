#!/usr/bin/env bash
# postflight.sh — Generate a WORKSHOP-REPORT.md summary after setup is complete.
#
# Usage (run from the kit directory):
#   bash scripts/postflight.sh [path/to/workshop-repo]
#
# If no path is given, looks for a sibling directory matching the repo_name in workshop-facts.yaml.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FACTS_FILE="$KIT_DIR/workshop-facts.yaml"

# ---------------------------------------------------------------------------
# Read facts
# ---------------------------------------------------------------------------

read_fact() {
    # Reads a scalar field; returns empty string if missing or null.
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

read_email() {
    # Reads people.contact_emails (list) with fallback to legacy people.contact_email (string).
    python3 - "$FACTS_FILE" <<'EOF'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
people = data.get("people", {}) or {}
emails = people.get("contact_emails")
if isinstance(emails, list):
    print(", ".join(str(e) for e in emails if e))
elif people.get("contact_email"):
    print(str(people["contact_email"]))
else:
    print("")
EOF
}

OWNER=$(read_fact "github.owner")
REPO_NAME=$(read_fact "github.repo_name")
TITLE=$(read_fact "workshop.title")
START=$(read_fact "event.start_date")
END=$(read_fact "event.end_date")
MODE=$(read_fact "event.mode")
VENUE=$(read_fact "event.venue")
EMAIL=$(read_email)
REGISTRATION=$(read_fact "links.registration")
NOTES_LINK=$(read_fact "links.collaborative_notes")

# Determine workshop repo path
if [[ -n "${1:-}" ]]; then
    REPO_DIR="$1"
else
    REPO_DIR="$KIT_DIR/../$REPO_NAME"
fi

REPO_URL="https://github.com/$OWNER/$REPO_NAME"
PAGES_URL="https://$OWNER.github.io/$REPO_NAME/"
REPORT_FILE="$REPO_DIR/WORKSHOP-REPORT.md"

# ---------------------------------------------------------------------------
# Scan for TBDs remaining in facts
# ---------------------------------------------------------------------------

TBDS=$(python3 - "$FACTS_FILE" <<'EOF'
import sys, yaml

def find_tbds(obj, path=""):
    found = []
    if isinstance(obj, str) and obj.strip().upper() == "TBD":
        found.append(path)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            found.extend(find_tbds(v, f"{path}.{k}" if path else k))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            found.extend(find_tbds(item, f"{path}[{i}]"))
    return found

data = yaml.safe_load(open(sys.argv[1]))
tbds = find_tbds(data)
for t in tbds:
    print(f"- `{t}` is still TBD")
EOF
)

TODAY=$(date +%Y-%m-%d)

# ---------------------------------------------------------------------------
# Generate report
# ---------------------------------------------------------------------------

mkdir -p "$REPO_DIR"

cat > "$REPORT_FILE" <<REPORT
# Workshop Setup Report

Generated: $TODAY

---

## Workshop

| Field | Value |
|---|---|
| Title | $TITLE |
| Mode | $MODE |
| Venue | $VENUE |
| Dates | $START to $END |
| Contact | $EMAIL |

## URLs

| | URL |
|---|---|
| GitHub repo | $REPO_URL |
| Live site | $PAGES_URL |
| Registration | $REGISTRATION |
| Collaborative notes | $NOTES_LINK |

## Site Status

Check the GitHub Actions tab to confirm the Pages build succeeded:
$REPO_URL/actions

If the build is failing, see the "Common Fixes" section in \`instructions/core.md\`.

## Remaining TBDs

$(if [[ -z "$TBDS" ]]; then echo "No TBD values remaining in workshop-facts.yaml."; else echo "$TBDS"; fi)

## Post-Setup Checklist

- [ ] Live site confirmed at $PAGES_URL
- [ ] Set repo description and website URL on GitHub → $REPO_URL (click "Edit")
- [ ] Email live URL to team@carpentries.org
- [ ] Fill out Self-Organized Workshop Form: https://amy.carpentries.org/forms/self-organised/ (if applicable)
- [ ] Create a separate learner practice repo if teaching Git
- [ ] Fill in any remaining TBDs listed above
REPORT

echo ""
echo "Report written to: $REPORT_FILE"
echo ""
cat "$REPORT_FILE"
