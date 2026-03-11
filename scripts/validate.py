#!/usr/bin/env python3
"""
Validate workshop-facts.yaml for Carpentries workshop website setup.

Usage:
    python3 scripts/validate.py [path/to/workshop-facts.yaml]

Exit codes:
    0 = valid
    1 = validation errors found
    2 = environment error (missing dependency, file not found)
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required.")
    print("       Install with:  pip install pyyaml")
    print("       Or on macOS:   brew install libyaml && pip install pyyaml")
    sys.exit(2)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CARPENTRY_VALUES = {"swc", "dc", "lc", "cp", "incubator"}
FLAVOR_VALUES = {"python", "r"}
MODE_VALUES = {"in-person", "online", "hybrid"}

# None means the curriculum field is flexible / no fixed allowed set
CURRICULUM_BY_CARPENTRY = {
    "swc": {"swc-inflammation", "swc-gapminder"},
    "dc": {"dc-ecology", "dc-astronomy", "dc-genomics", "dc-geospatial", "dc-image", "dc-socsci"},
    "lc": None,
    "cp": None,
    "incubator": None,
}

# ISO 3166-1 alpha-2 sample set — not exhaustive, catches obvious errors
KNOWN_COUNTRIES = {
    "us", "gb", "ca", "au", "nz", "de", "fr", "es", "it", "nl", "se",
    "no", "dk", "fi", "ch", "at", "be", "pt", "ie", "za", "br", "mx",
    "jp", "kr", "cn", "in", "sg", "nz",
}

# ISO 639-1 sample set
KNOWN_LANGUAGES = {
    "en", "fr", "es", "de", "it", "pt", "nl", "sv", "no", "da", "fi",
    "ja", "ko", "zh", "ar", "ru", "pl", "cs", "hu", "ro", "tr",
}

# Patterns that indicate an unfilled placeholder (beyond "TBD")
PLACEHOLDER_PATTERNS = [
    re.compile(r"\[.+?\]"),        # [your name], [institution]
    re.compile(r"\bFIXME\b"),
    re.compile(r"\bCHANGEME\b"),
    re.compile(r"<[^>]+>"),        # <owner>, <email>
    re.compile(r"YOUR_"),
    re.compile(r"example\.com"),
]

REPO_NAME_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z][a-z0-9\-]*[a-z0-9]$")
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def _fmt(label, msg):
    return f"  {label:<8}{msg}"

def _ok(msg):    print(_fmt("OK", msg))
def _warn(msg):  print(_fmt("WARN", msg))
def _err(msg):   print(_fmt("ERROR", msg))   # used for inline reporting, not final list


# ---------------------------------------------------------------------------
# Field helpers
# ---------------------------------------------------------------------------

def get_field(data, dotted_path):
    """Return (value, found). value is None when explicitly null."""
    parts = dotted_path.split(".")
    obj = data
    for part in parts:
        if not isinstance(obj, dict) or part not in obj:
            return None, False
        obj = obj[part]
    return obj, True


def is_tbd(value):
    return isinstance(value, str) and value.strip().upper() == "TBD"


def has_placeholder(value):
    if not isinstance(value, str):
        return False
    if is_tbd(value):
        return False
    return any(p.search(value) for p in PLACEHOLDER_PATTERNS)


def scan_placeholders(obj, path=""):
    """Return list of dotted paths that contain unfilled placeholders."""
    found = []
    if isinstance(obj, str):
        if has_placeholder(obj):
            found.append(path)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            child = f"{path}.{k}" if path else k
            found.extend(scan_placeholders(v, child))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            found.extend(scan_placeholders(item, f"{path}[{i}]"))
    return found


def parse_date(value):
    """Return (date_obj, error_string). Uses stdlib only."""
    from datetime import date, datetime
    if isinstance(value, date) and not isinstance(value, datetime):
        return value, None
    if isinstance(value, datetime):
        return value.date(), None
    if isinstance(value, str):
        if not DATE_PATTERN.match(value):
            return None, f"'{value}' is not in YYYY-MM-DD format"
        try:
            return datetime.strptime(value, "%Y-%m-%d").date(), None
        except ValueError as exc:
            return None, str(exc)
    return None, f"expected a date string, got {type(value).__name__}"


# ---------------------------------------------------------------------------
# Main validator
# ---------------------------------------------------------------------------

def validate(facts_path: Path):
    errors = []
    warnings = []

    # --- Load YAML ---
    try:
        raw = facts_path.read_text(encoding="utf-8")
        data = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        print(f"\nERROR: Could not parse {facts_path}:\n  {exc}\n")
        return False

    if not isinstance(data, dict):
        print(f"\nERROR: {facts_path} must be a YAML mapping at the top level.\n")
        return False

    print(f"\nValidating {facts_path}")
    print("=" * 60)

    # --- workshop.title ---
    title, found = get_field(data, "workshop.title")
    if not found or not title:
        errors.append("workshop.title is required")
    else:
        _ok(f"workshop.title = {title!r}")

    # --- workshop.carpentry ---
    carpentry, _ = get_field(data, "workshop.carpentry")
    if not carpentry:
        errors.append("workshop.carpentry is required (swc | dc | lc | cp | incubator)")
    elif carpentry not in CARPENTRY_VALUES:
        errors.append(
            f"workshop.carpentry '{carpentry}' is not valid. "
            f"Must be one of: {', '.join(sorted(CARPENTRY_VALUES))}"
        )
    else:
        _ok(f"workshop.carpentry = {carpentry}")

    # --- workshop.curriculum ---
    curriculum, _ = get_field(data, "workshop.curriculum")
    if carpentry and carpentry in CURRICULUM_BY_CARPENTRY:
        allowed = CURRICULUM_BY_CARPENTRY[carpentry]
        if allowed is None:
            # flexible — any value or TBD is fine
            if curriculum and not is_tbd(str(curriculum)):
                _ok(f"workshop.curriculum = {curriculum}")
        elif not curriculum or is_tbd(str(curriculum)):
            if carpentry == "dc":
                errors.append(
                    f"workshop.curriculum is required for Data Carpentry. "
                    f"Allowed: {', '.join(sorted(allowed))}"
                )
            else:
                warnings.append(f"workshop.curriculum is empty for '{carpentry}'")
        elif curriculum not in allowed:
            warnings.append(
                f"workshop.curriculum '{curriculum}' is not a known value for '{carpentry}'. "
                f"Expected one of: {', '.join(sorted(allowed))}"
            )
        else:
            _ok(f"workshop.curriculum = {curriculum}")

    # --- workshop.flavor ---
    flavor, found = get_field(data, "workshop.flavor")
    if flavor and flavor not in FLAVOR_VALUES:
        errors.append(
            f"workshop.flavor '{flavor}' must be one of: {', '.join(sorted(FLAVOR_VALUES))}"
        )
    elif flavor:
        _ok(f"workshop.flavor = {flavor}")

    # --- event.start_date / end_date ---
    raw_start, _ = get_field(data, "event.start_date")
    raw_end, _ = get_field(data, "event.end_date")

    parsed_start = parsed_end = None

    if not raw_start:
        errors.append("event.start_date is required (YYYY-MM-DD)")
    else:
        parsed_start, err = parse_date(raw_start)
        if err:
            errors.append(f"event.start_date: {err}")
        else:
            _ok(f"event.start_date = {parsed_start}")

    if not raw_end:
        errors.append("event.end_date is required (YYYY-MM-DD)")
    else:
        parsed_end, err = parse_date(raw_end)
        if err:
            errors.append(f"event.end_date: {err}")
        else:
            _ok(f"event.end_date = {parsed_end}")

    if parsed_start and parsed_end and parsed_end < parsed_start:
        errors.append("event.end_date must be on or after event.start_date")

    # --- event.mode ---
    mode, _ = get_field(data, "event.mode")
    if not mode:
        errors.append("event.mode is required (in-person | online | hybrid)")
    elif mode not in MODE_VALUES:
        errors.append(
            f"event.mode '{mode}' must be one of: {', '.join(sorted(MODE_VALUES))}"
        )
    else:
        _ok(f"event.mode = {mode}")

    # --- event.venue ---
    venue, _ = get_field(data, "event.venue")
    if not venue:
        errors.append("event.venue is required")
    else:
        _ok(f"event.venue = {venue!r}")

    # --- event.address ---
    address, _ = get_field(data, "event.address")
    if not address:
        errors.append(
            "event.address is required — use the full street address for in-person, "
            "or \"online\" for virtual workshops"
        )
    else:
        _ok(f"event.address = {address!r}")

    # --- event.country ---
    country, _ = get_field(data, "event.country")
    if not country:
        errors.append("event.country is required (ISO 3166-1 alpha-2, e.g. us, gb, ca)")
    elif not isinstance(country, str) or len(country) != 2 or not country.isalpha():
        errors.append(
            f"event.country '{country}' must be a 2-letter ISO country code (e.g. us, gb, ca)"
        )
    else:
        country_lower = country.lower()
        if country_lower not in KNOWN_COUNTRIES:
            warnings.append(
                f"event.country '{country}' is not in the known country list — "
                "verify it is a valid ISO 3166-1 alpha-2 code"
            )
        else:
            _ok(f"event.country = {country}")

    # --- event.language ---
    language, _ = get_field(data, "event.language")
    if not language:
        errors.append("event.language is required (ISO 639-1, e.g. en, fr, es)")
    elif not isinstance(language, str) or len(language) != 2 or not language.isalpha():
        errors.append(
            f"event.language '{language}' must be a 2-letter ISO language code (e.g. en, fr, es)"
        )
    else:
        lang_lower = language.lower()
        if lang_lower not in KNOWN_LANGUAGES:
            warnings.append(
                f"event.language '{language}' is not in the known language list — "
                "verify it is a valid ISO 639-1 code"
            )
        else:
            _ok(f"event.language = {language}")

    # --- people.instructors ---
    instructors, found = get_field(data, "people.instructors")
    if not found or not instructors:
        errors.append("people.instructors is required and must be a non-empty list")
    elif not isinstance(instructors, list):
        errors.append("people.instructors must be a YAML list (use '- Name' format)")
    else:
        blanks = [i for i, v in enumerate(instructors) if not v or (isinstance(v, str) and not v.strip())]
        if blanks:
            errors.append(f"people.instructors has blank entries at position(s): {blanks}")
        else:
            _ok(f"people.instructors = {len(instructors)} listed")

    # --- people.helpers ---
    helpers, found = get_field(data, "people.helpers")
    if found and helpers is not None:
        if not isinstance(helpers, list):
            errors.append("people.helpers must be a YAML list")
        else:
            blanks = [i for i, v in enumerate(helpers) if not v or (isinstance(v, str) and not v.strip())]
            if blanks:
                warnings.append(f"people.helpers has blank entries at position(s): {blanks}")
            else:
                _ok(f"people.helpers = {len(helpers)} listed")

    # --- people.contact_emails ---
    # Supports both contact_emails (list, preferred) and legacy contact_email (string)
    contact_emails, found_list = get_field(data, "people.contact_emails")
    contact_email_legacy, found_legacy = get_field(data, "people.contact_email")

    if found_list and contact_emails is not None:
        if not isinstance(contact_emails, list):
            errors.append("people.contact_emails must be a YAML list")
        else:
            bad = [e for e in contact_emails if e and not is_tbd(str(e)) and not EMAIL_PATTERN.match(str(e))]
            if bad:
                errors.append(f"people.contact_emails has invalid addresses: {bad}")
            elif not contact_emails:
                errors.append("people.contact_emails must contain at least one email address")
            else:
                _ok(f"people.contact_emails = {contact_emails}")
    elif found_legacy and contact_email_legacy:
        # Legacy single-string field — accept but warn
        warnings.append(
            "people.contact_email (singular) is deprecated. "
            "Use people.contact_emails (list) instead."
        )
        if not is_tbd(str(contact_email_legacy)) and not EMAIL_PATTERN.match(str(contact_email_legacy)):
            errors.append(f"people.contact_email '{contact_email_legacy}' is not a valid email address")
        else:
            _ok(f"people.contact_email = {contact_email_legacy} (legacy field)")
    else:
        errors.append(
            "people.contact_emails is required — provide a list of contact email addresses"
        )

    # --- github.owner ---
    owner, _ = get_field(data, "github.owner")
    if not owner:
        errors.append("github.owner is required (GitHub org or username)")
    else:
        _ok(f"github.owner = {owner}")

    # --- github.repo_name ---
    repo_name, _ = get_field(data, "github.repo_name")
    if not repo_name:
        errors.append("github.repo_name is required (e.g. 2026-05-11-uc-lc)")
    else:
        if not REPO_NAME_PATTERN.match(str(repo_name)):
            errors.append(
                f"github.repo_name '{repo_name}' is invalid. "
                "Must follow YYYY-MM-DD-<slug> where slug is lowercase, starts with a letter, "
                "and does not end with - or _"
            )
        elif parsed_start:
            expected_prefix = parsed_start.strftime("%Y-%m-%d")
            if not str(repo_name).startswith(expected_prefix):
                errors.append(
                    f"github.repo_name '{repo_name}' must start with the start date: {expected_prefix}"
                )
            else:
                _ok(f"github.repo_name = {owner}/{repo_name}")

    # --- Placeholder scan ---
    found_placeholders = scan_placeholders(data)
    if found_placeholders:
        errors.append(
            f"Unresolved placeholder text found in: {', '.join(found_placeholders)}. "
            "Replace with real values or use TBD."
        )

    # --- Print warnings ---
    for w in warnings:
        _warn(w)

    # --- Summary ---
    print()
    if errors:
        print(f"FAILED — {len(errors)} error(s):\n")
        for e in errors:
            print(f"  ✗  {e}")
        print()
        print("Fix the errors above, then re-run:  python3 scripts/validate.py")
        print()
        return False
    else:
        print("PASSED — workshop-facts.yaml is valid.")
        if warnings:
            print(f"         {len(warnings)} warning(s) shown above — review before proceeding.")
        print()
        return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) > 1:
        path = Path(sys.argv[1])
    else:
        candidates = [Path("workshop-facts.yaml"), Path("../workshop-facts.yaml")]
        path = next((p for p in candidates if p.exists()), Path("workshop-facts.yaml"))

    if not path.exists():
        print(f"\nERROR: {path} not found.")
        print("       Copy from examples/ and fill in your workshop details.")
        print("       Example:  cp examples/lc-online.yaml workshop-facts.yaml")
        print()
        sys.exit(2)

    success = validate(path)
    sys.exit(0 if success else 1)
