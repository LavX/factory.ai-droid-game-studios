# Setup Requirements

This template requires a few tools to be installed for full functionality.
Hooks carry on without an optional tool and lose only the check it powers. The
required ones are required: without Python 3 every setting falls back to its
default and a commit that stages data JSON is blocked, and without Bash no hook
runs at all.

## Required

| Tool | Purpose | Install |
| ---- | ---- | ---- |
| **Git** | Version control, branch management | [git-scm.com](https://git-scm.com/) |
| **Factory Droid** | AI agent CLI | Native installer: `curl -fsSL https://app.factory.ai/cli \| sh` (macOS, Linux) or `irm https://app.factory.ai/cli/windows \| iex` (Windows PowerShell). Homebrew: `brew install --cask droid`. npm also works: `npm install -g droid`. See [docs.factory.ai](https://docs.factory.ai) |
| **Python 3** | Reads `project.yaml` for every skill and hook | [python.org](https://www.python.org/). Without it every setting silently falls back to its default, and a commit that stages data JSON is blocked because it cannot be validated |
| **Bash** | Runs every hook | Built into macOS and Linux. On Windows, install [Git for Windows](https://git-scm.com/downloads/win) — Factory Droid runs without it, but no CCGS hook does |

## Recommended

| Tool | Used By | Purpose | Install |
| ---- | ---- | ---- | ---- |
| **jq** | Hooks (8 of 12) | JSON parsing in commit/push/asset/agent hooks | See below |

### Installing jq

**Windows** (any of these):
```
winget install jqlang.jq
choco install jq
scoop install jq
```

**macOS**:
```
brew install jq
```

**Linux**:
```
sudo apt install jq     # Debian/Ubuntu
sudo dnf install jq     # Fedora
sudo pacman -S jq       # Arch
```

## Platform Notes

### Windows
- Git for Windows includes **Git Bash**, which provides the `bash` command that the hooks need
- Hooks run `bash` on `.factory/hooks/run-hook.sh`, so `bash` must be on the PATH that Droid uses. If hooks fail with a missing `bash` error, add the folder that holds Git's `bash.exe` to PATH

### macOS / Linux
- Bash is available natively
- Install `jq` via your package manager for full hook support

## Verifying Your Setup

Run these commands to check prerequisites:

```bash
git --version          # Should show git version
bash --version         # Should show bash version
jq --version           # Should show jq version (optional)
python --version       # Required: Python 3 (python3 or py also work)
```

## What Happens Without Optional Tools

| Missing Tool | Effect |
| ---- | ---- |
| **jq** | The destructive-command guard needs jq. Without it, the guard allows every call. `run-hook.sh` also needs jq for its full payload rewrite; without it, it falls back to a `sed` rewrite that covers only the tool names and the `old_str`, `new_str`, and `change_all` fields. Session start prints a jq notice when jq is missing. |
| **Python 3** | Not optional (see Required). Every setting falls back to its default, because `project.yaml` is read through Python; the asset hook skips JSON validation and says so; a commit that stages data JSON is blocked. |
| **Both** | As without Python. |

## Settings and Permissions

Personal Droid settings live in `~/.factory/settings.json`. This project's settings live in `.factory/settings.json`. Local overrides go in `.factory/settings.local.json`, which is gitignored. The settings reference is on docs.factory.ai.

A new session starts with Autonomy Level Off, so file edits and commands wait for your approval unless a permission rule allows them. To change the default for your own sessions, set `sessionDefaultSettings.autonomyLevel` (`off`, `low`, `medium`, or `high`) in `~/.factory/settings.json`.

The `permissionRules` in `.factory/settings.json` allow a few read-only helper commands and block some destructive ones. The hook guard in `.factory/hooks/` blocks more. Project rules take effect only in a trusted workspace. Run `droid rules check` after you edit them.

Some keys from the original Claude-only guide do not apply to Droid: `permissions.defaultMode`, `claude --permission-mode`, `promptCacheTtl`, `subagentPromptCacheTtl`, `autoCompactWindow`, `skillListingBudgetFraction`, and `skillListingMaxDescChars`. Droid's settings reference does not list them, so do not add them to your settings.

Droid's `sandbox` setting isolates shell commands from your filesystem and network. Read the Sandbox page on docs.factory.ai before you turn it on.

## Recommended IDE

Droid runs from VS Code, Cursor, Windsurf, JetBrains IDEs, Zed, or any editor terminal. See docs.factory.ai for editor setup.
