<p align="center">
  <h1 align="center">Game Studios for Factory Droid</h1>
  <p align="center">
    Turn a single Factory Droid session into a full game development studio.
    <br />
    49 agents. 74 skills. One coordinated AI team.
  </p>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href=".factory/droids"><img src="https://img.shields.io/badge/agents-49-blueviolet" alt="49 Agents"></a>
  <a href=".factory/skills"><img src="https://img.shields.io/badge/skills-74-green" alt="74 Skills"></a>
  <a href=".factory/hooks"><img src="https://img.shields.io/badge/hooks-15-orange" alt="15 Hooks"></a>
  <a href=".factory/rules"><img src="https://img.shields.io/badge/rules-14-red" alt="14 Rules"></a>
  <a href="https://docs.factory.ai"><img src="https://img.shields.io/badge/built%20for-Factory%20Droid-f5f5f5" alt="Built for Factory Droid"></a>
</p>

---

> **Unofficial port.** This is an unofficial port of Claude Code Game Studios 1.2.0 (upstream commit `05ad7c8`) to Factory Droid. It is not made or endorsed by the upstream author. Agents are in `.factory/droids/`, skills are in `.factory/skills/`, and hooks are configured in `.factory/hooks.json`. `AGENTS.md` lists what differs from the upstream version. Issues with this port go to this fork. Issues with the upstream framework go to [Donchitos](https://github.com/Donchitos/Claude-Code-Game-Studios/issues).

## Why This Exists

Building a game solo with AI is powerful — but a single chat session has no structure. No one stops you from hardcoding magic numbers, skipping design docs, or writing spaghetti code. There's no QA pass, no design review, no one asking "does this actually fit the game's vision?"

**Claude Code Game Studios** (upstream, ported here to Factory Droid) solves this by giving your AI session the structure of a real studio. Instead of one general-purpose assistant, you get 49 specialized agents organized into a studio hierarchy — directors who guard the vision, department leads who own their domains, and specialists who do the hands-on work. Each agent has defined responsibilities, escalation paths, and quality gates.

The result: you still make every decision, but now you have a team that asks the right questions, catches mistakes early, and keeps your project organized from first brainstorm to launch.

---

## Table of Contents

- [What's Included](#whats-included)
- [Studio Hierarchy](#studio-hierarchy)
- [Slash Commands](#slash-commands)
- [Does it produce games, or documents?](#does-it-produce-games-or-documents)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Upgrading](#upgrading)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Design Philosophy](#design-philosophy)
- [Customization](#customization)
- [Platform Support](#platform-support)
- [Community](#community)
- [License](#license)

---

## What's Included

| Category | Count | Description |
|----------|-------|-------------|
| **Agents** | 49 | Specialized subagents across design, programming, art, audio, narrative, QA, and production |
| **Skills** | 74 | Slash commands for every workflow phase (`/start`, `/design-system`, `/create-epics`, `/create-stories`, `/dev-story`, `/story-done`, etc.) |
| **Hooks** | 15 | Automated validation on commits, pushes, asset changes, design-doc reads, writes and registries, session lifecycle, agent audit trail, and gap detection |
| **Rules** | 14 | Path-scoped coding guidance for gameplay, engine, AI, UI, network code, scene and asset files, and more. Not loaded automatically: AGENTS.md tells the agent to read the matching file before it edits a covered path |
| **Templates** | 62 | Document templates for GDDs, UX specs, ADRs, sprint plans, HUD design, accessibility, and more |

## Studio Hierarchy

Agents are organized into three tiers, matching how real studios operate:

```
Tier 1 — Directors
  creative-director    technical-director    producer

Tier 2 — Department Leads
  game-designer        lead-programmer       art-director
  audio-director       narrative-director    qa-lead
  release-manager      localization-lead

Tier 3 — Specialists
  gameplay-programmer  engine-programmer     ai-programmer
  network-programmer   tools-programmer      ui-programmer
  systems-designer     level-designer        economy-designer
  technical-artist     sound-designer        writer
  world-builder        ux-designer           prototyper
  performance-analyst  devops-engineer       analytics-engineer
  security-engineer    qa-tester             accessibility-specialist
  live-ops-designer    community-manager
```

Each droid sets its model in `.factory/droids/`. The three directors
(`creative-director`, `producer`, `technical-director`) use `claude-sonnet-5-5`
with `reasoningEffort: xhigh`. The other 46 droids use `claude-haiku-5-5` with
`reasoningEffort: max`. Factory's models page lists `xhigh` and `max` for these
models. Factory's droid docs list only `low`, `medium`, and `high`, so the
effort levels used here are not covered by those docs. Skills have no model
setting and run on your session model.

### Engine Specialists

The template includes agent sets for all three major engines. Use the set that matches your project:

| Engine | Lead Agent | Sub-Specialists |
|--------|-----------|-----------------|
| **Godot 4** | `godot-specialist` | GDScript, Shaders, GDExtension |
| **Unity** | `unity-specialist` | DOTS/ECS, Shaders/VFX, Addressables, UI Toolkit |
| **Unreal Engine 5** | `unreal-specialist` | GAS, Blueprints, Replication, UMG/CommonUI |

## Slash Commands

Type `/` in Factory Droid to access all 74 skills:

**Onboarding & Navigation**
`/start` `/help` `/project-stage-detect` `/setup-engine` `/adopt` `/settings`

**Game Design**
`/brainstorm` `/map-systems` `/design-system` `/quick-design` `/review-all-gdds` `/propagate-design-change`

**Art & Assets**
`/art-bible` `/asset-spec` `/asset-audit`

**UX & Interface Design**
`/ux-design` `/ux-review`

**Architecture**
`/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest`

**Stories & Sprints**
`/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/sprint-status` `/story-readiness` `/story-done` `/estimate`

**Reviews & Analysis**
`/design-review` `/code-review` `/balance-check` `/content-audit` `/scope-check` `/perf-profile` `/tech-debt` `/gate-check` `/consistency-check` `/security-audit`

**QA & Testing**
`/qa-plan` `/smoke-check` `/soak-test` `/regression-suite` `/test-setup` `/test-helpers` `/test-evidence-review` `/test-flakiness` `/skill-test` `/skill-improve`

**Production**
`/milestone-review` `/retrospective` `/bug-report` `/bug-triage` `/reverse-document` `/playtest-report`

**Release**
`/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix` `/day-one-patch`

**Creative & Content**
`/prototype` `/vertical-slice` `/onboard` `/localize`

**Team Orchestration** (coordinate multiple agents on a single feature)
`/team-combat` `/team-narrative` `/team-ui` `/team-release` `/team-polish` `/team-audio` `/team-level` `/team-live-ops` `/team-qa`

## Does it produce games, or documents?

A fair question, and the answer is a measurement rather than a sample project.
The figures below are **upstream results** from Claude Code Game Studios, not
measurements of this port. Four games were built from one brief at different
`modes.rigor` levels and the documents each wrote **before its first line of
game code** were counted:

| `modes.rigor` | Docs before first line of game code | Time |
|---|---:|---:|
| `minimal` | **1** (the one-page brief) | 0 min |
| `standard` | 30 | 58 min |

All of them produced a running, tested game. Two blind reviewers and a human
playtest then ranked the `standard` build **last** — the extra 29 documents
bought traceability, not a better game.

### It runs the game and looks at it

The measurement above is about cost. The other half is whether the thing works,
and for a game that means someone has to *look* at it — a passing test says
nothing about a menu drawn off-screen. So a story that changes anything the
player sees is not closed until the game has been launched, observed, and a
screenshot retained in `production/qa/evidence/`. A parse check is not a run.
This holds at every rigor level, including `minimal`, where automated tests are
waived but the look is not.

The games themselves are deliberately **not** shipped here: this is a template
you clone to start your own project, and somebody else's game in your repo is
clutter, not evidence.

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Factory Droid](https://docs.factory.ai) — install with `curl -fsSL https://app.factory.ai/cli | sh` (macOS, Linux), `irm https://app.factory.ai/cli/windows | iex` (Windows PowerShell), `brew install --cask droid`, or `npm install -g droid`
- [Python 3](https://www.python.org/) — reads `project.yaml` for every skill and hook; without it every setting silently falls back to its default
- Bash — runs every hook; built into macOS and Linux, and on Windows it comes with [Git for Windows](https://git-scm.com/downloads/win)
- **Recommended**: [jq](https://jqlang.github.io/jq/) (for hook validation)

Hooks fail gracefully if optional tools are missing — you just lose validation — with one deliberate exception: a commit that stages data JSON is blocked when there is no Python to validate it. The destructive-command guard needs `jq`. Without `jq` it allows every call, and `session-start.sh` prints a notice saying so.

### Setup

1. **Clone the port or use it as a template**. Upstream does not contain `AGENTS.md` or `.factory/`, so clone this fork:
   ```bash
   git clone https://github.com/LavX/factory.ai-droid-game-studios.git my-game
   cd my-game
   ```

2. **Open Factory Droid in the project's root folder** (the one holding
   `AGENTS.md` and `project.yaml`) and start a session:
   ```bash
   droid
   ```
   Starting it in a subfolder such as `src/` may skip the project's hooks, deny
   rules and ask-first permission mode.

3. **Run `/start`** — the system asks where you are (no idea, vague concept,
   clear design, existing work) and guides you to the right workflow. No assumptions.

   Or jump directly to a specific skill if you already know what you need:
   - `/brainstorm` — explore game ideas from scratch
   - `/setup-engine godot 4.7` — configure your engine if you already know
   - `/project-stage-detect` — analyze an existing project

## Configuration

`project.yaml` at the repo root is the single source of truth for how the
studio behaves on your project — engine, naming conventions, and a `modes`
block that controls how much process every skill enforces. `/start` writes it
for you; you rarely need to hand-edit it.

The one question that matters most is **`modes.rigor`** — `minimal`, `standard`,
or `full`. It's a single front door over six separate knobs (`workflow` —
which GDD sections are required, `docs.density`, `qa.level`,
`story_granularity`, `review_mode` — how many director agents review your work,
and `team.size`), so `/start` asks it once instead of six times:

- **`minimal`** (default) — jam-game speed. No GDDs required, terse docs, minimal QA evidence, solo review. `/start` → `/setup-engine` → `/brainstorm` (a one-page brief) → `/create-stories` → `/dev-story` ↔ `/story-done`.
- **`standard`** — 5 required GDD sections, balanced doc depth, standard QA evidence, lean review.
- **`full`** — all 8 GDD sections, thorough docs, full QA evidence on every story type, full director review.

`minimal` is the default because the heavier tier costs more to reach working
code without producing a better result, and gives nothing back when someone new
picks the project up. Raise it in one `/settings` call when your project grows
— `/help` and `/gate-check` will suggest it when they see the signs.

Two escape hatches keep one setting from being a blunt instrument.
**`system_overrides`** holds a single system to a higher standard than the rest
of the project — your combat system gets the full treatment while everything
else stays light. **`testing.strict`** sets, per test type (logic, integration,
visual, UI, config), whether missing evidence blocks a story or merely warns.

Any of the six underlying knobs can still be set individually if you want a mix
(e.g. `workflow: full` with `docs.density: terse` — comprehensive but compact).
Two of them — `review_mode` (`full` / `lean` / `solo`) and `team.size` — are
also **personal**: rigor sets the team-wide default, but you can override them
per-developer in a gitignored `project.local.yaml` without touching the shared
config. `modes.automation` (how often the AI pauses to ask before it acts) sits
outside rigor and is likewise personally overridable.

View or change any setting with the `/settings` skill:

```
/settings                              # view effective config
/settings modes.review_mode            # view one setting
/settings modes.rigor=full             # write to project.yaml (team-wide)
/settings --local modes.review_mode=solo   # write to project.local.yaml (just you)
```

Full schema and per-setting behavior: `.factory/docs/effects-map.md`.

## Upgrading

Already using an older version of this template? See [UPGRADING.md](UPGRADING.md)
for step-by-step migration instructions, a breakdown of what changed between
versions, and which files are safe to overwrite vs. which need a manual merge.

`CHANGELOG.md` and `UPGRADING.md` are upstream files, kept as they were. Their
upgrade steps are written for the upstream project and do not apply to this port.

## Project Structure

```
AGENTS.md                           # Master configuration
.factory/
  settings.json                     # Permissions, statusLine, safety rules
  hooks.json                        # Hook wiring: which events run which hook scripts
  droids/                           # 49 droid definitions (markdown + YAML frontmatter)
  skills/                           # 74 slash commands (subdirectory per skill)
  hooks/                            # 21 files (bash): run-hook.sh (the adapter every entry
                                    #   runs through), 15 wired event hook scripts, two sourced
                                    #   helpers (yaml-helper.sh, update-check.sh), test-guard.sh
                                    #   (guard regression test), and validate-agent-artifact.sh
                                    #   and log-instructions.sh, which are not wired (no Factory event)
  rules/                            # 14 path-scoped coding standards
  statusline.sh                     # Status line script (context%, model, stage, epic breadcrumb)
  docs/
    workflow-catalog.yaml           # 7-phase pipeline definition (read by /help)
    templates/                      # 62 document templates (+ per-section guidance)
src/                                # Game source code (Godot). The code root is
                                    #   ENGINE-SPECIFIC: Unity compiles only
                                    #   Assets/, Unreal builds from Source/<Module>/
assets/                             # Art, audio, VFX, shaders, data files
design/                             # GDDs, narrative docs, level designs
docs/                               # Technical documentation and ADRs
tests/                              # Test suites (unit, integration, performance, playtest)
tools/                              # Build and pipeline tools
prototypes/                         # Throwaway prototypes (isolated from src/)
production/                         # Sprint plans, milestones, release tracking
studio-tests/                       # QA for the skills and agents themselves — see below
```

The game folders in this tree (`src/`, `assets/`, `tests/`, `tools/`, `prototypes/`) appear as the project is set up, and this repo ships only the studio's own folders.

### Testing your customizations

Game Studios is a template you are meant to edit. `studio-tests/` is how
you check that an edited or newly written skill still holds up — a catalog of all
74 skills and 49 agents, per-category quality rubrics, behavioral specs, and
templates for writing specs of your own.

```
/skill-test static [name]     # structural linter — 7 compliance checks
/skill-test category [name]   # category-specific quality rubric
/skill-test spec [name]       # behavioral spec assertions
/skill-test audit             # coverage report across skills and agents
/skill-improve [name]         # test-fix-retest loop; keeps or reverts on score change
```

It tests the *framework*, never your game — game tests live in `tests/`.

## How It Works

### Agent Coordination

Agents follow a structured delegation model:

1. **Vertical delegation** — directors delegate to leads, leads delegate to specialists
2. **Horizontal consultation** — same-tier agents can consult each other but can't make binding cross-domain decisions
3. **Conflict resolution** — disagreements escalate up to the shared parent (`creative-director` for design, `technical-director` for technical)
4. **Change propagation** — cross-department changes are coordinated by `producer`
5. **Domain boundaries** — agents don't modify files outside their domain without explicit delegation

### Collaborative, Not Autonomous

This is **not** an auto-pilot system. Every agent follows a strict collaboration protocol:

1. **Ask** — agents ask questions before proposing solutions
2. **Present options** — agents show 2-4 options with pros/cons
3. **You decide** — the user always makes the call
4. **Draft** — agents show work before finalizing
5. **Approve** — nothing gets written without your sign-off

You stay in control. The agents provide structure and expertise, not autonomy.

That is how a terminal session started at the project root behaves out of the
box. The `guided` and `autonomous` automation settings, and Factory Droid's own
auto mode, trade some of these prompts for speed; see
[setup-requirements.md](.factory/docs/setup-requirements.md) for the routes into
auto mode.

### Automated Safety

**Hooks** run automatically on every session:

| Hook | Trigger | What It Does |
|------|---------|--------------|
| `guard-destructive.sh` | PreToolUse (Execute, Create, Edit, Read, Grep) | Blocks destructive commands, and reads or writes of `.env` files (see Destructive-command guard below) |
| `validate-commit.sh` | PreToolUse (Execute) | Checks for hardcoded values, TODO format, JSON validity, design doc sections — exits early if the command is not `git commit` |
| `validate-push.sh` | PreToolUse (Execute) | Warns on pushes to protected branches, and on `git tag`, `git merge`, `gh release`, `butler push` and `steamcmd +run_app_build` — exits early for any other command |
| `validate-read.sh` | PreToolUse (Read) | Refuses a whole-file read of a design doc over 40 KB and answers with its headings, so the retry reads one section (`features.read_guard`) |
| `validate-write.sh` | PreToolUse (Create/Edit) | Warns, never blocks, when a write would break a rule the skills state: a file they never overwrite, the config guard, the prototype boundary, a localization freeze |
| `validate-registry.sh` | PreToolUse (Create/Edit) | Warns when a write to the entity or TR-ID registry would delete or renumber an entry, or set a status its header does not list |
| `validate-assets.sh` | PostToolUse (Create/Edit) | Checks data-file JSON under `assets/`, `Assets/` or `Content/`, and asset naming in Godot's `assets/` only — exits early if the file is under none of them |
| `session-start.sh` | Session open | Shows current branch and recent commits for orientation |
| `detect-gaps.sh` | Session open | Detects fresh projects (suggests `/start`) and missing design docs when code or prototypes exist |
| `pre-compact.sh` | Before compaction | Logs the compaction (its output does not reach Droid — `session-start.sh` restores context afterwards) |
| `notify.sh` | Permission prompt, or idle about a minute | Shows Windows toast notification via PowerShell |
| `session-stop.sh` | Every response end | Archives `active.md` to session log and records git activity |
| `log-agent.sh` | Agent spawned | Audit trail start — logs subagent invocation |
| `log-agent-stop.sh` | Agent stops | Audit trail stop — completes subagent record |
| `validate-agent-artifact.sh` | Not wired in this port | Kept for reference. Not registered in `hooks.json`. It would warn when a subagent stops without writing the file its brief named |
| `validate-skill-change.sh` | PostToolUse (Create/Edit) | Advises running `/skill-test` after any `.factory/skills/` change |

> **Note**: `validate-commit.sh`, `validate-push.sh`, `validate-read.sh`, `validate-write.sh`, `validate-registry.sh`, `validate-assets.sh` and `validate-skill-change.sh` fire on every Execute, Read, Create or Edit tool call and exit immediately (exit 0) when the command or file path is not relevant. This is normal hook behavior — not a performance concern.

**Destructive-command guard** (`.factory/hooks/guard-destructive.sh`) checks Execute (shell) commands, Create, Edit and Read calls, and Grep calls whose path names a `.env` file. It blocks:

- `rm` with both recursive and force flags, in any flag order, in short form, in long form, or as a unique long-option prefix such as `--recurs --forc`, and PowerShell `rm -Recurse -Force` (PowerShell parameters match in any case and by unambiguous prefix, such as `-rec` and `-fo`)
- `del`, `erase`, `rd`, `rmdir`, `ri` and `Remove-Item` with `-Recurse` (or `-r`)
- `git reset --hard` (also `--ha`)
- `git push` with `--force`, `--force-with-lease`, `--mirror`, `-f`, or a `+refspec`
- `git clean` with `-f` or `--force` (also `--f`)
- `sudo`
- `chmod 777`, `0777` or `00777`, including `chmod -R 777`, and modes with a leading setuid, setgid or sticky digit from 1 to 7, such as `1777`, `3777`, `5777`, `6777` and `7777`
- A shell that reads its commands from stdin, such as `echo ... | sh` or `bash -s`, a pipe into `powershell`, `pwsh` or `cmd` with no command switch, and `at` or `batch` fed by a pipe or a here-string
- A command word with an unquoted glob or brace pattern, except `[`, `[[`, `{`, `}` and `!`. Brace groups are expanded in every word, nested groups included, and sequences such as `{1..5}` and `{a..e..2}` expand too, so `rm --{recursive,force} target`, `chmod {7,6}77 target` and `r{m..m} -rf target` are checked as the expanded command. Quoted braces stay literal. A word that expands to more than 4096 words, a command whose words expand to more than 4096 words in all, or a brace word that needs more than 10000 steps to scan, is blocked as too complex.
- PowerShell `Get-Content`, `Set-Content`, `Add-Content` and `Out-File` on `.env` names and globs, and redirects into or out of `.env` files
- Reads, copies, links and archives of `.env` files by file commands such as `cat`, `head`, `grep`, `sed`, `cp`, `tar`, `openssl`, `nvim`, `xz`, `split` and `certutil`, including glob, bracket and brace forms that match one of the names `.env`, `.envrc`, `.env.local`, `.env.example`, `.env.production`, `.env.development`, `.env.test` or `.env.staging`, such as `.e*`, `.?nv`, `[.]env` and `.{env,x}`, and tar's attached name forms such as `tar -cf.env` and `tar -f.env`. In a shell word, a pattern counts only when it starts with a literal `.` or `[`, because shell globs skip dot files, so `cat ?env` and `cat *` pass. `find -name`, `-iname`, `-path` and `-ipath`, and PowerShell names, match any glob, so `find . -name '*' -exec cat {} +` is blocked
- `ln` to a `.env` name, and `find` with `-name`, `-iname`, `-path` or `-ipath` naming `.env` when the same command also has `-exec`, `-execdir`, `-ok`, `-okdir` or a pipe
- `git show HEAD:.env` and `git add .env`
- Reads through the Read tool, and writes through the Create and Edit tools, of `.env*` files, including `.env.example`
- Create and Edit paths with trailing dots or spaces, or a colon suffix such as `.env::$DATA`, are checked as the bare name (the same applies to `.uasset` and `.umap` edits)
- Grep calls whose path names a `.env` file (a folder path is not checked)
- Edits of `.uasset` and `.umap` files

The guard reads shell text the way the shell does, as far as a pattern check can. It skips comments (a `#` after an escaped character is part of the word), unwraps wrappers such as `env`, `nohup`, `timeout`, `setsid`, `wsl`, `su`, `doas`, `pkexec`, `runuser`, `watch`, `flock`, `script`, `strace`, `chroot`, `parallel`, `setarch`, `eatmydata`, `systemd-run`, `unshare` and `coproc` with their short and GNU long value options (such as `timeout --signal TERM`), and decodes quotes and `$'...'` escapes, and cuts a `$'...'` string at a decoded NUL (such as `\0`, `\x00`, `\000` or `\400`), as bash does. It follows nested `$( )` and `$(( ))`. It decodes heredoc delimiters as the shell does: a delimiter with any quoting (`'EOF'`, `"EOF"`, `\EOF` or `$'EOF'`) makes the body literal, and an unquoted delimiter also checks `$( )` and backticks in the body, so a closing `EOF` line does not hide a later `rm -rf` line. It recognizes unambiguous prefixes of the pattern-taking long options, grep's `--regexp` (from `--reg`) and `--file` (exact only), and sed's `--expression` (from `--e`) and `--file` (from `--fi`), so `grep --reg=x .env` and `sed --exp=p .env` are blocked. An ambiguous prefix such as grep's `--re` or `--f` is not read as a pattern option. It checks redirect targets, heredoc bodies, `env -S` (including option clusters such as `env -iS`), `trap` (including `trap -- ...`), function bodies, and the commands inside `sh -c`, `bash -c`, `bash --rcfile FILE -s`, `cmd /c`, `eval`, `powershell -Command`, `iex` and `Invoke-Expression` with a quoted string, the operands of `powershell` or `pwsh` with no command switch, the `-c` value of `fish`, `rbash`, `mksh`, `csh`, `tcsh` and `ksh93`, the `-c` or `--command` value of the wrappers above, and `find -exec`.

It does not check variables, aliases, shell functions called by name, command substitution output, interpreters (`python -c`, `node -e`, `perl`, `ruby`, awk `system()`), PowerShell `-EncodedCommand` and .NET method calls such as `[IO.File]::ReadAllText`, `iex` or `Invoke-Expression` with a string built at run time, commands run on another machine by `ssh`, `rd /s` and `del /s`, deleting a `.env` file with `rm`, `del` or `find -delete`, `\u` and `\U` escapes inside `$'...'`, a glob or bracket name for a `.env` file that is not one of the names above (such as `.[e]nv.custom`), brace groups with stray `}` characters (such as `{}{}x,}`), readers, editors and wrappers outside the lists (such as `curl`, `nc`, `notepad`, `xdg-open`, `fakeroot`, `nsenter`, `bwrap`, `firejail`, `tmux` and `screen`), attached option values that name a file except `tar -f` (such as `sort -o.env`), ApplyPatch edits, MultiEdit (Factory's hook docs list no such tool), `Glob` and `LS` calls, Grep calls on folder paths (`Grep` can show the text of a `.env` file), or files that a script reads. Inside double quotes, a `)` that closes a `case` pattern in `$( )` ends the substitution early, so `"$(case x in x) echo;; esac; sudo id)"` is not blocked. An option that takes a separate value is skipped only when it is in the guard's value lists (the wrapper options and the shell `--rcfile` and `--init-file`), so an unlisted value option hides the word after it. The guard has three budgets. A command is blocked when it exceeds one of them: more than 256 KB of shell text, counted in bytes with nested text included; more than 5,000 simple-command checks, where a text with a backslash is parsed twice, so its commands count twice; or a check that runs longer than 15 seconds. The timer starts when the guard starts, before it reads the payload, and a watchdog applies the same limit inside the parser, so a long word cannot run past it. The adapter's jq pass runs before the guard and is not timed. The 15-second limit keeps the guard's own work inside its 30-second hook timeout, because Factory's hook docs do not say whether a timed-out hook blocks or allows the call. A command that the guard waits for, such as jq or tr, cannot be interrupted, so a stall there delays the block until it returns. Nested wrappers cost more than their text, so for them the time limit is the bound that holds. Measured on a 16-core development machine (one-minute load average from 2.5 to 5.9 during the runs): a 2,000-line heredoc takes about 3.5 seconds, 2,000 `true` commands about 1.7 seconds, a 100 KB word about 6 seconds, a 256 KB word and a chain of 400 `watch` wrappers are blocked at the 15-second limit, and ten levels of nested `su -c` text take about 10 seconds.

Some false positives are kept on purpose: a heredoc body line that starts with a blocked command, a name that starts with `.env` such as `docs/.environment.md` or a commit message that starts with `.envrc`, `git push --dry-run --force`, a backslash inside a path such as `cat docs\.env`, text after a backslash-escaped dollar such as `echo \$(rm -rf x)`, a command word with a glob such as `./run-*.sh`, a value given by `-e` or `-f`, which is checked as a file (so `grep -e .env docs` is blocked), a `$( )` or backtick outside single quotes in the body of a quoted heredoc (`<<"EOF"` with `$(sudo id)` in the body, which the shell does not run), a `find -name` glob with a pipe such as `find . -name '*.*' -print | sort`, and words after the user of `su`, or after the file of `flock`, when a `-c` value came first, such as `su -c 'echo ok' root rm -rf x`, which the guard reads as commands. `rm .env` is a limit, not a false positive.

It needs `jq`. Without `jq`, the guard allows every call. With `jq`, the guard blocks a payload that cannot be read, is empty, is not one tool call, or has no string tool name. `run-hook.sh` exits 2 when its directory cannot be found, when the payload cannot be read, or when a rewrite fails. With `jq`, it also exits 2 for a payload that is empty or is not one JSON object, for a field it cannot read, or for a session id it cannot filter. The hook timeout for the guard in `.factory/hooks.json` is 30 seconds.

**Permission rules** in `.factory/settings.json` (`permissionRules`) are a separate layer. They have 10 rules. Five block: recursive forced `rm`, `git reset --hard`, git push force forms, git clean force forms, and `chmod 777`. Five allow: pytest runs (`python` and `py` launchers), `dir`, the read-only `project.yaml` lookups in `yaml-helper.sh`, and `story-status.sh`. Prefix rules cover command prefixes only. The `rm` rule matches only the flag clusters `-rf`, `-fr`, `-Rf` and `-fR`, so forms such as `rm -r -f` and `rm --recursive --force` match no rule and rely on the destructive-command guard. There is no `permissionRules` entry for `sudo` or for `.env` files; the guard handles those. Project permission rules need a trusted workspace. At the Off autonomy level, Droid's built-in policy allows read commands such as `git status`, `ls` and `pwd` without a rule. Permission rules are prefix rules that match exact, ordered argument tokens at the start of a command. They are not regexes.

### Path-Scoped Rules

Factory does not load `.factory/rules/*` automatically. Before Droid edits a
covered path, it reads the matching rule file, and the path table in `AGENTS.md`
says which file covers which path. The paths below are Godot's. Each rule also matches the Unity and Unreal layouts: the code
rules match C# under `Assets/**/Gameplay/` and C++ under `Source/**/Gameplay/` (and `Core`,
`AI`, `Networking`, `UI`), data matches JSON under `Assets/**/Data/` and
`Content/**/Data/`, shaders match by file type, and tests match
C# under `Assets/Tests/` and C++ under `Source/**/Tests/`.

| Path | Enforces |
|------|----------|
| `src/gameplay/**` | Data-driven values, delta time usage, no UI references |
| `src/core/**` | Zero allocations in hot paths, thread safety, API stability |
| `src/ai/**` | Performance budgets, debuggability, data-driven parameters |
| `src/networking/**` | Server-authoritative, versioned messages, security |
| `src/ui/**` | No game state ownership, localization-ready, accessibility |
| `design/gdd/**` | Required sections per `modes.workflow`, formula format, edge cases |
| `design/narrative/**` | Lore consistency, character voice, canon levels |
| `assets/data/**/*.json` | JSON validity, naming conventions, schema rules |
| `assets/shaders/**` | Naming conventions, performance targets, cross-platform rules |
| `**/*.tscn`, `**/*.tres` | Scene and resource files changed in the editor where possible; safe hand-edit rules |
| `tests/**` | Test naming, coverage requirements, fixture patterns |
| `prototypes/**` | Relaxed standards, README required, hypothesis documented |

## Design Philosophy

This template is grounded in professional game development practices:

- **MDA Framework** — Mechanics, Dynamics, Aesthetics analysis for game design
- **Self-Determination Theory** — Autonomy, Competence, Relatedness for player motivation
- **Flow State Design** — Challenge-skill balance for player engagement
- **Bartle Player Types** — Audience targeting and validation
- **Verification-Driven Development** — Tests first, then implementation

## Customization

This is a **template**, not a locked framework. Everything is meant to be customized:

- **Add/remove agents** — delete agent files you don't need, add new ones for your domains
- **Edit agent prompts** — tune agent behavior, add project-specific knowledge
- **Modify skills** — adjust workflows to match your team's process
- **Add rules** — create new path-scoped rules for your project's directory structure
- **Tune hooks** — adjust validation strictness, add new checks
- **Pick your engine** — use the Godot, Unity, or Unreal agent set (or none)
- **Tune process weight** — `modes.rigor` and its underlying knobs in `project.yaml` (see [Configuration](#configuration)). Override per-run with `--review solo` on any skill.

## Platform Support

**Upstream results:** the upstream project did its primary development on **Windows 10** with Git Bash, and tested its hooks and scripts on **macOS** (stock bash 3.2 and BSD tools, with and without `jq`) and on **Linux**. Those results come from the upstream framework, not from this port. All hooks use POSIX-compatible patterns (`grep -E`, not `grep -P`) and include fallbacks for missing tools. The `notify.sh` hook uses PowerShell for Windows toast notifications and is a no-op elsewhere — desktop notifications on macOS/Linux are not yet wired.

**Verified for this port:**

- Shell scripts pass `bash -n`
- `.factory/hooks.json` and `.factory/settings.json` parse as JSON
- The 49 droid names match their filenames
- The models are listed on Factory's models page
- The guard regression cases in `.factory/hooks/test-guard.sh` pass

**Not verified in a live session:** the statusline payload, organization-level enforcement of `permissionRules`, `ApplyPatch` hook coverage, and the `team-*` skills end to end.

Please file issues for any platform-specific breakage in this port with the fork.

## Community

Issues are split by where the problem is:

- **Issues with this Factory Droid port** — file them on this fork's issue tracker.
- **Issues with the upstream framework** (Claude Code Game Studios itself) — file them with Donchitos.

Upstream community links, which do not cover this port:

- **Discussions** — [GitHub Discussions](https://github.com/Donchitos/Claude-Code-Game-Studios/discussions) for questions, ideas, and showcasing what you've built
- **Issues** — [Bug reports and feature requests](https://github.com/Donchitos/Claude-Code-Game-Studios/issues)

---

*Unofficial Factory Droid port of Claude Code Game Studios 1.2.0. Port issues go to this fork; upstream framework issues go to [Donchitos](https://github.com/Donchitos/Claude-Code-Game-Studios/issues).*

## License

MIT License. See [LICENSE](LICENSE) for details.
