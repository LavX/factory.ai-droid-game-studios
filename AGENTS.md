# Claude Code Game Studios (Factory Droid port) -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Factory Droid subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Factory Droid Runtime Notes

This copy is an unofficial port of Claude Code Game Studios (upstream release 1.2.0) to Factory Droid. It runs on Factory Droid. The framework was written for Claude Code, so these points differ from the upstream text. Pages that describe the upstream Claude Code runtime are reference only (see the Claude-only point below).

- **No CLAUDE.md or `.claude/` folder.** This copy has no `CLAUDE.md` and no `.claude/` folder. `AGENTS.md` replaces `CLAUDE.md`, and `.factory/` replaces `.claude/`.
- **Agents are droids.** They live in `.factory/droids/`. The three upstream opus directors (creative-director, producer, technical-director) run on `claude-sonnet-5-5` with `reasoningEffort: xhigh`. The other 46 droids run on `claude-haiku-5-5` with `reasoningEffort: max`. Factory's models page on docs.factory.ai lists xhigh and max for both models. Droid's subagent docs describe `reasoningEffort` in droid frontmatter as accepting low, medium, or high.
- **Skills are slash commands.** They live in `.factory/skills/` and run as `/skill-name`. Their `model:` settings were dropped, so skills run on the session model. Upstream `!` bootstrap lines are now explicit steps: run the command first and use its output. `$ARGUMENTS` became the text the user typed after the skill name.
- **Droids cannot ask or delegate.** Factory droids run as subagents and cannot call AskUser or Task. A droid that needs a user decision, or another droid's work, puts the request in its report. Only the main session asks the user and starts droids.
- **Write checks are advisory and partial.** `validate-write.sh` warns and never blocks. Factory's hook docs list no field that names the droid making a tool call, so rules that depend on the droid name do not run. Path checks still run. If Droid edits a file with `ApplyPatch`, the Create and Edit hooks may not run for that edit.
- **Path rules are not loaded automatically.** Read the matching rule file before you edit a path it covers:

| Rule file | Paths it covers |
| --- | --- |
| `.factory/rules/agent-memory.md` | `.factory/agent-memory/**` |
| `.factory/rules/ai-code.md` | `src/ai/**`; `Assets/**/{AI,Ai,ai}/**/*.cs`; `Source/**/{AI,Ai,ai}/**/*.{h,cpp}` |
| `.factory/rules/data-files.md` | `assets/data/**/*.json`; `Assets/**/{Data,data}/**/*.json`; `Content/**/{Data,data}/**/*.json` |
| `.factory/rules/design-docs.md` | `design/gdd/**` |
| `.factory/rules/engine-code.md` | `src/core/**`; `Assets/**/{Core,core}/**/*.cs`; `Source/**/{Core,core}/**/*.{h,cpp}` |
| `.factory/rules/gameplay-code.md` | `src/gameplay/**`; `Assets/**/{Gameplay,gameplay}/**/*.cs`; `Source/**/{Gameplay,gameplay}/**/*.{h,cpp}` |
| `.factory/rules/narrative.md` | `design/narrative/**` |
| `.factory/rules/network-code.md` | `src/networking/**`; `Assets/**/{Networking,networking,Network,network}/**/*.cs`; `Source/**/{Networking,networking,Network,network}/**/*.{h,cpp}` |
| `.factory/rules/prototype-code.md` | `prototypes/**` |
| `.factory/rules/scene-files.md` | `**/*.tscn`; `**/*.tres`; `**/*.unity`; `**/*.prefab`; `Assets/**/*.asset` |
| `.factory/rules/shader-code.md` | `assets/shaders/**`; `**/*.gdshader`; `Assets/**/*.{shader,hlsl,cginc,compute,shadergraph}`; `Shaders/**`; `**/*.{usf,ush}` |
| `.factory/rules/skill-authoring.md` | `.factory/skills/**`; `.factory/droids/**` |
| `.factory/rules/test-standards.md` | `tests/**`; `Assets/Tests/**/*.cs`; `Source/**/Tests/**/*.{h,cpp}` |
| `.factory/rules/ui-code.md` | `src/ui/**`; `Assets/**/{UI,Ui,ui}/**/*.cs`; `Source/**/{UI,Ui,ui}/**/*.{h,cpp}` |

- **`@` imports are not relied on.** This copy inlines the upstream imports for directory structure, coordination rules, and coding standards above, so it does not depend on `@` handling. The engine reference import stays as a literal line because `/setup-engine` rewrites it. Read the engine reference file when a task needs the pinned engine version.
- **Hooks run through an adapter.** `.factory/hooks.json` calls `.factory/hooks/run-hook.sh`, which converts Factory payloads (`Create`, `Execute`, `old_str`, `new_str`, `change_all`) to the shape the hook scripts expect. The adapter skips session hooks when the SessionStart payload carries `calling_session_id`. Factory's hook docs do not list that field, so this behavior is unverified. The adapter exits 2 when its directory cannot be found, when the payload cannot be read, or when a rewrite fails. On a PreToolUse call, exit 2 blocks the call. Other events give exit 2 other effects, as the adapter header explains. With `jq`, it also exits 2 when the payload is empty or is not one JSON object, when a field it reads cannot be read, or when the session id cannot be filtered.
- **Destructive-command guard.** `.factory/hooks/guard-destructive.sh` checks Execute (shell) commands, Create, Edit and Read calls, and Grep calls whose path names a `.env` file. It blocks recursive forced `rm` (any flag order, long-option prefixes, PowerShell `-Recurse` and `-Force` in any case or by unambiguous prefix), `del`, `erase`, `rd`, `rmdir`, `ri` and `Remove-Item` with `-Recurse` or `-r`, `git reset --hard` (also `--ha`), force-push forms (including `--mirror`), `git clean` with `-f` or `--force` (also `--f`), `sudo`, `chmod 777` (any number of leading zeros, and a leading setuid, setgid or sticky digit from 1 to 7, such as `1777`, `3777`, `5777`, `6777` and `7777`), a shell that reads its commands from stdin (`| sh`, `bash -s`), a pipe into `powershell`, `pwsh` or `cmd` with no command switch, `at` or `batch` fed by a pipe or here-string, and a command word with an unquoted glob or brace pattern (except `[`, `[[`, `{`, `}` and `!`). Brace groups are expanded in every word, nested groups and sequences such as `{1..5}` included, and quoted braces stay literal, so `rm --{recursive,force} target` and `chmod {7,6}77 target` are checked as the expanded command. A word that expands to more than 4096 words, a command whose words expand to more than 4096 words in all, or a brace word that needs more than 10000 steps to scan, is blocked as too complex. It blocks reads, writes and redirects of `.env*` files: PowerShell `Get-Content`, `Set-Content`, `Add-Content` and `Out-File`; file commands such as `cat`, `head`, `grep`, `sed`, `cp`, `tar`, `openssl`, `nvim`, `xz`, `split` and `certutil`, `ln` to a `.env` name, and `find` naming `.env` with `-exec`, `-ok` or a pipe; glob, bracket and brace forms that match one of the names `.env`, `.envrc`, `.env.local`, `.env.example`, `.env.production`, `.env.development`, `.env.test` or `.env.staging` (such as `.e*`, `[.]env` and `.{env,x}`; in a shell word a pattern counts only when it starts with a literal `.` or `[`, so `cat ?env` passes, while `find -name` and PowerShell names match any glob); attached names such as `tar -cf.env`; and `git show HEAD:.env` and `git add .env`. It blocks Read, Create and Edit calls on `.env*` files, including `.env.example`, and Create and Edit paths with trailing dots or spaces or a colon suffix such as `.env::$DATA` (checked as the bare name). It blocks edits of `.uasset` and `.umap` files, with the same name handling. It checks commands inside `sh -c`, `bash -c`, `cmd /c`, `eval`, `powershell -Command`, `iex` and `Invoke-Expression` with a quoted string, the operands of `powershell` or `pwsh` with no command switch, the `-c` value of `fish`, `rbash`, `mksh`, `csh`, `tcsh` and `ksh93`, the value of `-c` or `--command` in the wrappers below, `trap` (including `trap -- ...`), `env -S` (including `-iS` clusters), function bodies, heredoc bodies and `find -exec`. A heredoc delimiter with any quoting makes the body literal, and an unquoted one also checks `$( )` and backticks in the body. Grep's `--regexp` (from `--reg`) and `--file` (exact), and sed's `--expression` (from `--e`) and `--file` (from `--fi`), are read as pattern options by unambiguous prefix; ambiguous prefixes such as `--re` or `--f` are not. Wrappers with value options are unwrapped: `env`, `nohup`, `timeout`, `setsid`, `wsl`, `su`, `doas`, `pkexec`, `runuser`, `watch`, `flock`, `script`, `strace`, `chroot`, `parallel`, `setarch`, `eatmydata`, `systemd-run`, `unshare` and `coproc`. Comments are skipped (a `#` after an escaped character is part of the word). A `$'...'` string is cut at a decoded NUL, as bash cuts it. Heredoc body lines are checked as commands, so a body line that starts with a blocked command is blocked too. It does not check ApplyPatch edits, MultiEdit (Factory's hook docs list no such tool), `Glob` and `LS` calls, Grep calls on folder paths (`Grep` can show the text of a `.env` file), interpreters such as `python -c`, `node -e`, `perl`, `ruby` or awk `system()`, PowerShell `-EncodedCommand` and .NET calls such as `[IO.File]::ReadAllText`, `iex` or `Invoke-Expression` with a string built at run time, commands run on another machine by `ssh`, readers, editors and wrappers outside the lists (such as `curl`, `nc`, `notepad`, `fakeroot`, `nsenter`, `bwrap`, `firejail`, `tmux` and `screen`), attached option values that name a file except `tar -f` (such as `sort -o.env`), files that scripts read, variables, aliases, functions called by name, command substitution results, `\u` and `\U` escapes inside `$'...'`, `rd /s`, `del /s`, a glob or bracket name for a `.env` file that is not one of the names above (such as `.[e]nv.custom`), brace groups with stray `}` characters (such as `{}{}x,}`), or deleting a `.env` file with `rm`, `del` or `find -delete`. Inside double quotes, a `)` that closes a `case` pattern in `$( )` ends the substitution early, so a command after a later `;` is not checked. An option that takes a separate value is skipped only when it is in the guard's value lists (the wrapper options, and the shell `--rcfile` and `--init-file`), so an unlisted value option hides the word after it. The guard has three budgets. A command is blocked when it exceeds one of them: more than 256 KB of shell text, counted in bytes with nested text included; more than 5,000 simple-command checks, where a text with a backslash is parsed twice, so its commands count twice; or a check that runs longer than 15 seconds. The timer starts when the guard starts, before it reads the payload, and a watchdog applies the same limit inside the parser, so a long word cannot run past it. The adapter's jq pass runs before the guard and is not timed. The 15-second limit keeps the guard's own work inside its 30-second hook timeout, because Factory's hook docs do not say whether a timed-out hook blocks or allows the call. A command that the guard waits for, such as jq or tr, cannot be interrupted, so a stall there delays the block until it returns. Nested wrappers cost more than their text, so for them the time limit is the bound that holds. Measured on a 16-core development machine (one-minute load average from 2.5 to 5.9 during the runs): a 2,000-line heredoc takes about 3.5 seconds, 2,000 `true` commands about 1.7 seconds, a 100 KB word about 6 seconds, a 256 KB word and a chain of 400 `watch` wrappers are blocked at the 15-second limit, and ten levels of nested `su -c` text take about 10 seconds. Some false positives are kept on purpose: a heredoc body line that starts with a blocked command, a name that starts with `.env` such as `docs/.environment.md` or a commit message that starts with `.envrc`, `git push --dry-run --force`, a backslash inside a path such as `cat docs\.env`, text after a backslash-escaped dollar such as `echo \$(rm -rf x)`, a command word with a glob such as `./run-*.sh`, a value given by `-e` or `-f` such as `grep -e .env docs`, a `$( )` or backtick outside single quotes in the body of a quoted heredoc, a `find -name` glob with a pipe, and words after the user of `su`, or after the file of `flock`, when a `-c` value came first, such as `su -c 'echo ok' root rm -rf x`, which the guard reads as commands. The guard needs `jq`. Without `jq`, it allows every call. With `jq`, the guard blocks a payload that cannot be read, is empty, is not one tool call, or has no string tool name, and `run-hook.sh` exits 2 for a payload that cannot be read, is empty or is not one JSON object, has a field it cannot read, or whose rewrite fails. The `permissionRules` in `.factory/settings.json` cover some of the same blocks as exact command prefixes: `rm -rf`, `git reset --hard`, `git push --force`, `git clean -f` and `chmod 777`. The hook is the only check for `sudo`, `.env` files and the other forms above. Project permission rules need a trusted workspace.
- **Command approvals.** `permissionRules` allow the read-only `project.yaml` lookups in `yaml-helper.sh` and `story-status.sh`, so the skills that read config do not prompt. At the Off Autonomy Level, Droid's built-in allowed commands include `ls` and `git status`, so `ls` runs without a prompt. `git log` is not among the documented examples, and `git log` and `git tag` may ask for approval unless the Autonomy Level allows them.
- **Local overrides.** Droid does not load `AGENTS.local.md`. Read it yourself, or copy the lines you need into `AGENTS.md`. Personal Droid settings go in `.factory/settings.local.json`, which is gitignored.
- **Update check.** `session-start.sh` makes no network call. A background job asks GitHub for the latest upstream release at most once a day, when the cache is missing or a day old. The check is off by default in this port, because `project.yaml` sets `updates: check: false`. It is also off when the `CI` environment variable is set. Set `check: true` under `updates:` to turn it on. The notice names the upstream release and says that this port is not upgraded automatically.
- **Not carried over.** The SubagentStart and InstructionsLoaded hooks (no Factory equivalent), `maxTurns` limits, `memory:` auto-loading (droids read `.factory/agent-memory/<name>/` themselves), skill preloading (droids read the listed skills), droid worktree isolation, and async hooks. The SubagentStop artifact check (`validate-agent-artifact.sh`) is not wired in this port, because Factory's SubagentStop hook docs do not list an `agent_transcript_path` field.
- **Claude-only pages.** These pages in `.factory/docs/` document the upstream Claude Code runtime, and their text still refers to Claude Code: `hooks-reference.md`, `hooks-reference/hook-input-schemas.md`, `model-tiers.md`, `agent-teams.md`, and `settings-local-template.md`. Do not copy their settings, hook payloads, or environment variables into Droid. Droid reads `.factory/settings.json` and `.factory/hooks.json`. `CLAUDE_CODE_*` variables in any page only apply to Claude Code. `.factory/scripts/compat-inventory.sh` is kept unchanged because it inventories Claude Code features.
- **Engine.** `project.yaml` has no engine yet. Choose one with `/setup-engine`, which also rewrites the engine reference import above.

## Technology Stack

- **Engine**: [CHOOSE: Godot 4 / Unity / Unreal Engine 5]
- **Language**: [CHOOSE: GDScript / C# / C++ / Blueprint]
- **Version Control**: Git with trunk-based development
- **Build System**: [SPECIFY after choosing engine]
- **Asset Pipeline**: [SPECIFY after choosing engine]

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

<!-- Inlined from .factory/docs/directory-structure.md. This copy does not rely on @ imports. -->
# Directory Structure

```text
/
├── AGENTS.md                    # Master configuration
├── project.yaml                 # Machine-readable project config — engine, modes, stage (source of truth)
├── .factory/                     # Agent definitions, skills, hooks, rules, docs
├── <code root>/                 # Game source code — THE PATH IS ENGINE-SPECIFIC, see below
├── assets/                      # Game assets (art, audio, vfx, shaders, data)
├── design/                      # Game design documents (gdd, narrative, levels, balance)
├── docs/                        # Technical documentation (architecture, api, postmortems)
│   └── engine-reference/        # Curated engine API snapshots (version-pinned)
├── tests/                       # Game test suites (unit, integration, performance, playtest)
├── tools/                       # Build and pipeline tools (ci, build, asset-pipeline)
├── prototypes/                  # Throwaway prototypes (outside the code root)
├── production/                  # Production management (sprints, milestones, releases)
│   ├── session-state/           # Ephemeral session state (active.md — gitignored)
│   └── session-logs/            # Session audit trail (gitignored)
└── studio-tests/                # QA for the skills/agents themselves — /skill-test, /skill-improve
```

## The code root is engine-specific

**Two of the three supported engines will not build a project whose code sits in
`src/`.** This is not a style preference — it is a hard constraint of the engine's
own toolchain:

| `engine.name` | Code root | Why it cannot be `src/` |
|---|---|---|
| **Godot** | `src/` | No constraint — Godot loads from `res://` anywhere under the project root. |
| **Unity** | `Assets/` | Unity compiles **only** `Assets/` and `Packages/`. Code outside them is invisible to the compiler. |
| **Unreal** | `Source/<Module>/` | UnrealBuildTool discovers modules under `Source/`; content lives in `Content/`. A module elsewhere is not built. |

**Resolve the code root from `engine.name` before writing any source file.** A
path shown as `src/…` alone is a Godot example: read it as *"the code root"* and
substitute the row above. `src/` is the table's Godot row, not a universal path.

**Tests follow the same rule** — the same compilers decide what they see:

| `engine.name` | Test root | Anywhere else |
|---|---|---|
| **Godot** | `tests/unit/`, `tests/integration/` | — |
| **Unity** | `Assets/Tests/EditMode/`, `Assets/Tests/PlayMode/` | not compiled: "0 tests, Passed" |
| **Unreal** | `Source/<Module>/Private/Tests/` | not built: "No automation tests matched" |

Read `tests/unit/[system]/` (or `integration/`) anywhere as the test root plus `[System]/`.

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line below is engine-specific. /setup-engine
     rewrites it to @docs/engine-reference/<engine>/VERSION.md for the chosen
     engine, so a Unity or Unreal project stops loading the Godot reference every
     session. It defaults to Godot (the template's example engine); skills that
     need the pinned version read docs/engine-reference/<engine>/VERSION.md on
     demand regardless of this import. -->
This copy does not rely on `@` imports, so the engine reference below is read on demand. Skills that need the pinned version read it themselves.
@docs/engine-reference/godot/VERSION.md


## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.factory/docs/config-resolution.md`).

`.factory/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

<!-- Inlined from .factory/docs/coordination-rules.md. This copy does not rely on @ imports. -->
# Agent Coordination Rules

1. **Vertical Delegation**: Leadership agents delegate to department leads, who
   delegate to specialists. Never skip a tier for complex decisions.
2. **Horizontal Consultation**: Agents at the same tier may consult each other
   but must not make binding decisions outside their domain.
3. **Conflict Resolution**: When two agents disagree, escalate to the shared
   parent. If no shared parent, escalate to `creative-director` for design
   conflicts or `technical-director` for technical conflicts.
4. **Change Propagation**: When a design change affects multiple domains, the
   `producer` agent coordinates the propagation.
5. **No Unilateral Cross-Domain Changes**: An agent must never modify files
   outside its designated directories without explicit delegation.
6. **Read Design Docs by Section**: A brief names the sections an agent needs
   by heading. Find a heading in a GDD, ADR or the art bible with the Grep
   tool (`^#`, content mode) and Read that range with offset and limit; read a doc
   whole only when the task needs all of it, and say why. `validate-read.sh`
   refuses a whole-file read of a doc over 40 KB.
7. **Nothing Goes Upstream**: Never file, open or comment on an issue or pull
   request in an engine, plugin or vendor repository, even when asked. Write a
   draft (`/bug-report` drafts only) and the user submits it.

## Model Tier Assignment

Skills in this copy do not set a model. They run on the session model, and the upstream `model:` lines were removed. Droids set their own model in `.factory/droids/`. The three directors run on `claude-sonnet-5-5` with `reasoningEffort: xhigh`, and the other 46 droids run on `claude-haiku-5-5` with `reasoningEffort: max`. Factory's models page lists xhigh and max. Droid's subagent docs describe `reasoningEffort` in droid frontmatter as accepting low, medium, or high. `.factory/docs/model-tiers.md` describes the upstream Claude Code tier table. It is kept as reference only and does not describe Droid's models.

## Subagents vs Agent Teams

This project uses two distinct multi-agent patterns:

### Subagents (current, always active)
Started by the main session, not by another droid. A subagent cannot call Task,
so it cannot start another droid, and AskUser is disabled for it. Used by all
`team-*` skills and orchestration skills. Subagents return results to the parent.

**When to start in parallel**: If two subagents' inputs are independent (neither
needs the other's output to begin), start both at the same time
rather than waiting. Example: `/review-all-gdds` **Phase 2** (consistency) and
**Phase 3** (design theory) are independent — start both at the same time.
Phase 1 loads the GDDs and both depend on it, so it is the one phase here that
must NOT be parallelised.

### Agent Teams (experimental, opt-in)
Not set up in this copy. The upstream feature needs an experimental flag that this copy has not mapped to Droid. Do not propose agent teams until that mapping is confirmed. `.factory/docs/agent-teams.md` is upstream reference only.

## Parallel Droid Protocol

When an orchestration skill starts multiple independent droids:

1. Start all independent droids before waiting for any result
2. Collect all results before proceeding to dependent phases
3. If any agent is BLOCKED, surface it immediately — do not silently skip
4. Always produce a partial report if some agents complete and others block

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Create/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.factory/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside the project root? Check that Droid loaded this project's
  hooks and permission rules before you rely on them.

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

<!-- Inlined from .factory/docs/coding-standards.md. This copy does not rely on @ imports. -->
# Coding Standards

- All game code must include doc comments on public APIs
- Architecture decisions are recorded as ADRs in `docs/architecture/`. **How many is
  set by `modes.workflow`** — all ADRs at `full`, *critical* ADRs only at `standard`,
  and none required at `minimal`, where the decision log and `design/game-brief.md`
  carry the rationale instead. See `.factory/docs/workflow-modes.md`.
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.
- **A parse check is not a run.** Every story that changes something
  player-observable is launched and observed before it closes, and the
  observation is a retained screenshot in `production/qa/evidence/`. Procedure
  per engine: `.factory/docs/run-and-observe.md`. Not waived at
  `qa.level: minimal` — tests are, the look is not.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- **How many of the 8 sections are required depends on `modes.workflow`** —
  all 8 at `full`, 5 (+ Formulas when the system defines numeric rules — rates,
  curves, thresholds, costs; the system's `Category` is a hint, not the test) at
  `standard`, and no
  GDD at all at `minimal`, where `design/game-brief.md` is the design record.
  See `.factory/docs/workflow-modes.md`. The 8 sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Default Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Retained screenshot + lead sign-off | `production/qa/evidence/` | BLOCKING |
| **UI** (menus, HUD, screens) | Retained screenshot of each screen touched | `production/qa/evidence/` | BLOCKING |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

The **Default Gate Level** applies when `testing.strict` is not set in
`project.yaml`. A project may override it per test type: `testing.strict.logic`,
`.integration`, `.visual`, `.ui`, and `.config` each take `true` (BLOCKING) or
`false` (ADVISORY). `/story-done`, `/story-readiness`, `/dev-story`,
`/gate-check`, and `/smoke-check` resolve the effective level from that setting,
falling back to the defaults above when it is absent.

> **Why Visual and UI block.** "Retained" is load-bearing — the screenshot must
> still be on disk in `production/qa/evidence/` when the story is closed. One
> that was captured and discarded is an assertion, not evidence. These two rows
> block because for a game the way it looks *is* the product: an advisory visual
> gate gets deferred in favour of whatever does block, and the result is a
> well-tested game that looks wrong.

> **Exception — `/smoke-check`.** The ADVISORY default for **Config/Data** above
> applies to *per-story evidence* gates. `/smoke-check` is a build-health gate,
> not a per-story evidence gate, so its own unset default for
> `testing.strict.config` is **BLOCKING**. The two defaults differ on purpose.

## Automated Test Rules

- **Naming**: per engine — `.factory/rules/test-standards.md`
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode`
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag

## Context Management

Read `.factory/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.factory/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
