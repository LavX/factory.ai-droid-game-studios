# AGENTS.local.md Template

Copy this file to the project root as `AGENTS.local.md` for personal overrides.
This file is gitignored and will not be committed.

```markdown
# Personal Preferences

## Model Preferences
- Prefer the director model (claude-sonnet-5-5 at xhigh) for complex design tasks
- Use claude-haiku-5-5 for quick lookups and simple edits (droid models are set in each droid's frontmatter in `.factory/droids/`)

## Workflow Preferences
- Always run tests after code changes
- Compact context proactively at 60% usage
- Use /clear between unrelated tasks

## Local Environment
- Python command: python (or py / python3)
- Shell: Git Bash on Windows
- IDE: VS Code with Factory Droid extension

## Communication Style
- Keep responses concise
- Show file paths in all code references
- Explain architectural decisions briefly

## Personal Shortcuts
- When I say "review", run /code-review on the last changed files
- When I say "status", show git status + sprint progress
```

## Setup

1. Copy this template to your project root: `cp .factory/docs/AGENTS-local-template.md AGENTS.local.md`
2. Edit to match your preferences
3. Verify `AGENTS.local.md` is in `.gitignore`. Droid does not load this file on its own. To use it, ask Droid to read `AGENTS.local.md` explicitly, or copy the lines you need into `AGENTS.md`.
