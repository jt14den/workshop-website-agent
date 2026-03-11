# AGENTS.md — Carpentries Workshop Website Agent

Full instructions are in `instructions/core.md`. Read that file first.
This file is kept substantive so agents that do not follow the pointer still have enough to work safely.

---

## What You Are Helping With

Creating and customizing a Carpentries workshop website from the official
[workshop-template](https://github.com/carpentries/workshop-template).
The result is a Jekyll site published via GitHub Pages.

Your role: read `workshop-facts.yaml`, configure key files in the workshop repo,
draft the schedule HTML, and apply known fixes. Scripts handle repo creation.

---

## Non-Negotiables

1. **Never fork.** Use `gh repo create <owner>/<repo> --template carpentries/workshop-template --public --clone`
2. **Work on `gh-pages` branch only.** Never commit to `main`.
3. **Repo name:** `YYYY-MM-DD-<slug>` — slug must not end with `-` or `_`
4. **Preserve all `_config.yml` variables.** Do not delete fields like `amy_site`, `pre_survey`, `post_survey`.
5. **Never invent details.** If it is not in `workshop-facts.yaml`, use `TBD`.

---

## Files to Edit (in the workshop repo)

### `_config.yml`

| Field | Valid values |
|---|---|
| `carpentry` | `swc`, `dc`, `lc`, `cp`, `incubator` |
| `curriculum` | SWC: `swc-inflammation`/`swc-gapminder`; DC: `dc-ecology`/`dc-astronomy`/`dc-genomics`/`dc-geospatial`/`dc-image`/`dc-socsci`; LC: flexible |
| `flavor` | `python` or `r` |
| `title` | Full workshop title |
| `repository` | `owner/repo-name` |

### `index.md` front matter

Map every field from `workshop-facts.yaml` to `index.md`:

| `workshop-facts.yaml` | `index.md` front matter |
|---|---|
| `workshop.title` | (used in page title) |
| `event.venue` | `venue` |
| `event.address` | `address` |
| `event.country` | `country` |
| `event.language` | `language` |
| `event.start_date` | `startdate` |
| `event.end_date` | `enddate` |
| `event.humandate` | `humandate` (derive: e.g. "May 11-20, 2026") |
| `event.daily_start`/`daily_end` + timezone | `humantime` (e.g. "9:00 am - 12:00 pm PT") |
| `people.instructors` | `instructor` (YAML list) |
| `people.helpers` | `helper` (YAML list) |
| `people.contact_emails` | `email` (YAML list) |
| `links.collaborative_notes` | `collaborative_notes` |
| `links.eventbrite_key` | `eventbrite` |

**Always remove** the `<div class="alert alert-danger">` block from `index.md` after filling in front matter.

### `_includes/<carpentry>/schedule.html`

Do not use Markdown tables in `index.md` — they break rendering.
Edit the HTML schedule file directly.

For multi-day workshops, use Bootstrap grid:
```html
<div class="row">
  <div class="col-md-6">
    <h3>Day 1 &mdash; Mon May 11</h3>
    <table class="table table-striped">
      <tr><td>09:00</td><td>Introduction and setup check</td></tr>
      <tr><td>09:15</td><td>Lesson episode title</td></tr>
      <tr><td>10:15</td><td>Break</td></tr>
      <tr><td>10:30</td><td>Lesson episode title</td></tr>
      <tr><td>11:45</td><td>Wrap-up and questions</td></tr>
      <tr><td>12:00</td><td>End</td></tr>
    </table>
  </div>
  <div class="col-md-6"><!-- Day 2 ... --></div>
</div>
```

---

## Common Fixes (apply proactively)

| Symptom | Fix |
|---|---|
| Build fails: `Could not locate included file 'syllabus.html'` | Create empty `_includes/syllabus.html` |
| Changes not appearing on live site | Add a unique HTML comment (e.g. `<!-- rebuild-2 -->`) and push |
| LC + Python: no Python setup shown | Add `{% include install_instructions/python.html %}` to `_includes/lc/setup.html` |
| `alert-danger` block still visible | Delete the `<div class="alert alert-danger">...</div>` block from `index.md` |

---

## Post-Setup Checklist

- [ ] Live site confirmed working
- [ ] Set repo description and website URL on GitHub
- [ ] Email live URL to `team@carpentries.org`
- [ ] Fill out [Self-Organized Workshop Form](https://amy.carpentries.org/forms/self-organised/) if applicable
- [ ] Create a separate learner practice repo if teaching Git

---

See `instructions/core.md` for the complete workflow, recovery guidance, and reference docs.
