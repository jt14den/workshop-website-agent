# Carpentries Workshop Website Agent Kit

A self-contained kit for setting up [Carpentries workshop websites](https://github.com/carpentries/workshop-template)
with the help of an AI coding agent. You fill in your event details, run one command,
and the agent handles the rest.

Works with Claude Code, GitHub Copilot CLI, Gemini CLI, and OpenAI Codex CLI.

---

## Before You Start

You need three things installed on your computer:

1. **GitHub CLI** — [install here](https://cli.github.com/), then run `gh auth login`
2. **Python 3** — usually already installed on Mac/Linux; [install here](https://python.org) if not
3. **PyYAML** — run `pip install pyyaml` in your terminal
4. **An AI agent CLI** — one of:
   - [Claude Code](https://claude.ai/code): `npm install -g @anthropic-ai/claude-code`
   - [Gemini CLI](https://github.com/google-gemini/gemini-cli): `npm install -g @google/gemini-cli`
   - GitHub Copilot: built into VS Code or `gh extension install github/gh-copilot`

You also need a GitHub account or organization where the workshop site will be published.

---

## Get the Kit

Clone this repository once. You'll reuse it for every future workshop.

```bash
git clone https://github.com/<org>/workshop-website-agent
cd workshop-website-agent
```

---

## For Each New Workshop

### 1. Copy an example and fill in your event details

```bash
# Pick the example closest to your workshop type:
cp examples/lc-online.yaml    workshop-facts.yaml   # Library Carpentry, online
cp examples/swc-inperson.yaml workshop-facts.yaml   # Software Carpentry, in-person
cp examples/dc-multiday.yaml  workshop-facts.yaml   # Data Carpentry, multi-day
```

Open `workshop-facts.yaml` in a text editor and fill in your details:
- Workshop title, carpentry type, and curriculum
- Dates, location, and mode (in-person / online / hybrid)
- Instructor and helper names
- Your GitHub username or org
- The repo name you want (must follow `YYYY-MM-DD-<abbreviation>`, e.g. `2026-05-11-uc-lc`)

Leave anything you don't know yet as `TBD`.

### 2. Run the setup assistant

```bash
./start-workshop
```

This will:
- Check that all tools are installed and you're logged into GitHub
- Validate your workshop facts and flag any errors
- Show a summary of your workshop details
- Offer to create the GitHub repository for you (with a dry-run preview)
- Print the exact prompt to paste into your AI agent

### 3. Start your AI agent and paste the prompt

```bash
# Start Claude Code (or your preferred agent) from this directory:
claude
```

Paste the prompt that `./start-workshop` printed. The agent will:
- Read the full instructions from `instructions/core.md`
- Read your workshop facts
- Configure `_config.yml` and `index.md`
- Build the schedule HTML
- Apply any fixes needed for your workshop type
- Walk you through the final checklist

### 4. Generate your summary report

After the agent session, run:

```bash
bash scripts/postflight.sh
```

This creates `WORKSHOP-REPORT.md` in your new workshop repo with the live URL,
any remaining TBDs, and the post-setup checklist.

---

## Validate Your Facts Without Starting a Session

```bash
python3 scripts/validate.py
```

Checks for: missing required fields, invalid dates, wrong repo name format,
incompatible curriculum/flavor combinations, and unfilled placeholder text.

---

## Preview Without Creating Anything

```bash
bash scripts/bootstrap-repo.sh --dry-run
```

Prints exactly what the bootstrap script would do — no changes made.

---

## How the Kit Is Structured

```
workshop-website-agent/
├── start-workshop                  ← run this first
├── workshop-facts.yaml             ← fill this in for each workshop
├── instructions/
│   └── core.md                     ← complete agent instructions (canonical)
├── scripts/
│   ├── validate.py                 ← validates workshop-facts.yaml
│   ├── preflight.sh                ← checks tools and auth
│   ├── bootstrap-repo.sh           ← creates the GitHub repo
│   └── postflight.sh               ← generates WORKSHOP-REPORT.md
├── schema/
│   └── workshop-facts.schema.yaml  ← field documentation
├── examples/
│   ├── lc-online.yaml
│   ├── swc-inperson.yaml
│   └── dc-multiday.yaml
├── AGENTS.md                       ← agent compatibility (Claude Code, Codex)
├── CLAUDE.md                       ← agent compatibility (Claude Code)
├── GEMINI.md                       ← agent compatibility (Gemini CLI)
└── .github/
    └── copilot-instructions.md     ← agent compatibility (GitHub Copilot)
```

`instructions/core.md` is the heart of the kit. It encodes the Carpentries-specific rules
that the agent must follow: what to never change, how to build the schedule HTML, what
commonly breaks and how to fix it. All the compatibility files (`AGENTS.md`, `CLAUDE.md`,
etc.) are thin shims that point agents to `instructions/core.md`.

---

## Sharing and Customising

**Share the whole kit:** Publish this repo in your GitHub org. Others clone it and go.

**Customise for your community:** Fork the kit and edit `instructions/core.md` to add
your org's defaults — standard contact email, favourite lessons, schedule format,
GitHub org name. This gives your community a pre-configured starting point.

**Share just the instructions:** If someone already has a workflow, they can copy
`instructions/core.md` into any directory and start an agent session from there.

---

## Troubleshooting

Common build issues and fixes are documented in `instructions/core.md` under "Common Fixes".
The agent applies them automatically, but they're listed there for reference.

If `./start-workshop` fails at the preflight stage, it will tell you exactly what to fix.

---

## Contributing

If you find a new build quirk, a better schedule pattern, or a missing step,
please open a PR. The goal is to keep `instructions/core.md` as the community's
shared knowledge base for this workflow.
