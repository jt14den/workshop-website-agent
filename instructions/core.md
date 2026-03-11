# Carpentries Workshop Website — Agent Instructions

This is the canonical instruction source for this kit.
All agent compatibility files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`)
point here. Read this file at the start of every session.

---

## What You Are Helping With

Creating and customizing a Carpentries workshop website from the official
[workshop-template](https://github.com/carpentries/workshop-template). The result is
a Jekyll site published via GitHub Pages at `https://<owner>.github.io/<repo-name>/`.

---

## Division of Labor

| Who | Does what |
|---|---|
| **Human (script)** | Preflight checks, repo creation, GitHub Pages setup, post-run report |
| **Agent (you)** | Reads facts, configures `_config.yml` and `index.md`, builds schedule HTML, applies fixes, flags issues |
| **Human (review)** | Confirms rendered site, fills in any TBDs, completes post-setup actions |

The scripts handle deterministic steps. Your job is judgment: drafting schedule HTML,
catching config errors, applying known fixes, and flagging anything that needs human input.

---

## Non-Negotiables

These rules apply to every workshop without exception. Do not deviate unless explicitly instructed.

1. **Never fork.** The repo must be created with the GitHub template function:
   ```bash
   gh repo create <owner>/<repo-name> --template carpentries/workshop-template --public --clone
   ```
   Forking copies extra branches and breaks the expected repo structure.

2. **Branch:** All work happens on `gh-pages`. Never commit to or create `main`.
   If you find yourself on `main`, stop and confirm with the user.

3. **Naming:** Repo name must follow `YYYY-MM-DD-<slug>` (e.g. `2026-05-11-uc-lc`).
   Append `-online` for virtual workshops if the convention is used locally.
   The slug must NOT end with `-` or `_` — the GitHub Pages build will fail silently.

4. **Preserve all `_config.yml` variables.** Do not delete or comment out fields like
   `amy_site`, `pre_survey`, `post_survey`, `collaborative_notes` even if unused —
   the Jekyll layouts reference them unconditionally.

5. **Never invent details.** If `workshop-facts.yaml` says `TBD`, leave it as `TBD`
   in the site. Do not substitute guesses or placeholder text.

---

## Reading the Input File

Always read `workshop-facts.yaml` before doing anything. It is the authoritative source
for all event details. If it has not been validated yet, tell the human to run:
```bash
./start-workshop
```
or directly:
```bash
python3 scripts/validate.py
```

If validation fails, stop and ask the human to fix the errors before continuing.

---

## Key Files to Edit (in the workshop repo)

### `_config.yml` — site-wide settings

| Field | Valid values |
|---|---|
| `carpentry` | `"swc"`, `"dc"`, `"lc"`, `"cp"`, `"incubator"` |
| `curriculum` | SWC: `swc-inflammation`, `swc-gapminder`; DC: `dc-ecology`, `dc-astronomy`, `dc-genomics`, `dc-geospatial`, `dc-image`, `dc-socsci`; LC: `lc` |
| `flavor` | `"r"` or `"python"` (omit or leave blank if not applicable) |
| `title` | Full workshop title string |
| `repository` | `owner/repo-name` (no URL, just the path) |

### `index.md` — homepage front matter

Fields to update from `workshop-facts.yaml`:
`venue`, `address`, `country`, `language`, `humandate`, `humantime`,
`startdate`, `enddate`, `instructor` (YAML list), `helper` (YAML list),
`email` (YAML list), `collaborative_notes`, `eventbrite`.

**Always remove** the `<div class="alert alert-danger">` template notice block
(usually spans ~20 lines near the top of the file body). Leaving it in is a common
oversight that makes the site look unfinished.

### `_includes/<carpentry>/schedule.html` — schedule

**HTML-first rule.** Do not build the schedule as a Markdown table inside `index.md`.
Markdown tables inside Jekyll liquid includes break rendering unpredictably.
Always edit the HTML schedule file in `_includes/<carpentry>/schedule.html`.

For multi-day workshops, use Bootstrap's grid layout for a professional side-by-side view:

```html
<div class="row">
  <div class="col-md-6">
    <h3>Day 1 &mdash; Mon May 11</h3>
    <table class="table table-striped">
      <tr> <td>09:00</td> <td>Introduction and setup check</td> </tr>
      <tr> <td>09:15</td> <td>Lesson: The Unix Shell — Navigating Files</td> </tr>
      <tr> <td>10:00</td> <td>Break</td> </tr>
      <tr> <td>10:15</td> <td>Lesson: The Unix Shell — Working with Files</td> </tr>
      <tr> <td>11:00</td> <td>Exercises</td> </tr>
      <tr> <td>11:45</td> <td>Wrap-up and questions</td> </tr>
      <tr> <td>12:00</td> <td>End</td> </tr>
    </table>
  </div>
  <div class="col-md-6">
    <h3>Day 2 &mdash; Tue May 12</h3>
    <table class="table table-striped">
      <!-- ... -->
    </table>
  </div>
</div>
```

Break each day into ~45-minute blocks aligned with official lesson episodes.
Include a 15-minute mid-session break and a "Wrap-up and questions" block before end time.

---

## GitHub Pages Setup

If not handled by `scripts/bootstrap-repo.sh`:

1. Confirm the default branch is `gh-pages` (not `main`).
2. Go to: Repo Settings → Pages → Build and deployment → Source: `Deploy from a branch` → Branch: `gh-pages` → `/` (root).
3. First build takes 2–5 minutes. Pages URL will be `https://<owner>.github.io/<repo-name>/`.

---

## Common Fixes (apply proactively)

| Symptom | Fix |
|---|---|
| Build fails: `Could not locate included file 'syllabus.html'` | Create an empty file at `_includes/syllabus.html` — `bootstrap-repo.sh` does this automatically |
| Pushed changes not appearing on live site | Add a unique HTML comment (e.g. `<!-- rebuild-2 -->`) anywhere in the changed include file and push |
| LC + Python: no Python setup instructions shown | Add `{% include install_instructions/python.html %}` to end of `_includes/lc/setup.html` |
| DC curriculum warning in build | Set `curriculum` in `_config.yml` to the correct value (e.g. `dc-ecology`) |
| Alert-danger block still visible on live site | Delete the `<div class="alert alert-danger">...</div>` block from `index.md` |
| Lessons list blank | The template doesn't auto-populate lessons — manually add lesson links in `index.md` or the schedule include |

---

## Post-Setup Checklist

When the site is live and confirmed, ensure these are done:

- [ ] Set repo **description** and **website URL** on GitHub (click "Edit" on the repo homepage)
- [ ] Email the live URL to `team@carpentries.org`
- [ ] Fill out the [Self-Organized Workshop Form](https://amy.carpentries.org/forms/self-organised/) if applicable
- [ ] Create a **separate** learner practice repo if teaching Git (never use the website repo for this)
- [ ] Run `scripts/postflight.sh` to generate the `WORKSHOP-REPORT.md` summary

---

## Recovery: Partial Setup States

If something went wrong mid-setup and you need to restart:

- **Repo created but not configured:** Resume from `_config.yml` edits. Do not delete and re-create — the Pages deployment is already in motion.
- **Pages not building:** Check Actions tab for errors. Most common causes: wrong branch, missing `syllabus.html`, malformed YAML in front matter.
- **Wrong branch committed to:** Do not force-push. Ask the human to confirm before any branch manipulation.
- **Config drift:** If `_config.yml` and `index.md` disagree on dates or details, treat `workshop-facts.yaml` as the authoritative source.

---

## Reference Docs

- Template repo: https://github.com/carpentries/workshop-template
- Customization guide: https://carpentries.github.io/workshop-template/customization/
- Video walkthrough: https://www.youtube.com/watch?v=_Ag1JiZzyUQ
