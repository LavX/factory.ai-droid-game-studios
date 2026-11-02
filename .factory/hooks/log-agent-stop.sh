#!/bin/bash

# --- work from the project root ----------------------------------------------
# Every path below is repo-relative, so a hook invoked with a working directory
# that is not the repo root would silently read and write the WRONG TREE --
# returning a near-empty result instead of the session-recovery block, and
# creating stray trees such as docs/production/session-logs/ on write.
#
# PRECEDENCE IS LOAD-BEARING. A cwd that IS a project root carries real
# information and must win: a caller sitting inside another project means that
# project, not this one. Resolving to the script's own location first would
# override them. So, in order:
#   1. cwd holds project.yaml   -> cwd   (a project root)
#   2. cwd holds .factory/       -> cwd   (a project root not yet configured),
#      unless cwd is itself named .factory: a stray .factory/.factory/ would
#      make .factory/ a root, and the hooks would write .factory/production/
#   3. FACTORY_PROJECT_DIR       -> that  (populated in the hook environment),
#      unless it names a .factory folder, for the same reason as rule 2
#   4. this script's location   -> <root>/.factory/hooks/../.. by construction
# Rule 4 always works and needs no environment at all; rules 1-2 stop it from
# overriding a caller that legitimately means somewhere else.
#
# NOT an upward search: that resolves a nested project to its parent's config.
if [ -f "project.yaml" ] || { [ -d ".factory" ] && [ "${PWD##*/}" != ".factory" ]; }; then
  CCGS_ROOT="$PWD"
elif [ -n "${FACTORY_PROJECT_DIR:-}" ] && [ -d "${FACTORY_PROJECT_DIR}" ] && case "${FACTORY_PROJECT_DIR%/}" in */.factory|*\\.factory) false ;; *) true ;; esac; then
  CCGS_ROOT="$FACTORY_PROJECT_DIR"
else
  CCGS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
fi
[ -n "$CCGS_ROOT" ] && cd "$CCGS_ROOT" 2>/dev/null || true

# Logs droid completion to the agent audit trail.
# Tracks when agents finish and their outcome.
#
# Wired in .factory/hooks.json as a SubagentStop hook (matcher ".*"). Factory's
# SubagentStop payload lists session_id, task_name, task_result, task_error and
# stop_hook_active. It does not list agent_transcript_path. run-hook.sh adds
# agent_type by finding the Task call recorded for the same description as
# task_name. If no Task call matches, agent_type is absent and the record is
# logged as "unknown".
#
# Upstream only, not in Factory's payload: a SubagentStop payload with agent_id,
# agent_type, agent_transcript_path and last_assistant_message.
#
# The agent name is in `agent_type`, NOT `agent_name`. Reading `.agent_name`
# returns null on every invocation, so the fallback "unknown" is always used
# and the audit trail captures nothing useful.

# features.session_state: off => no audit trail. Default `on`; see
# session_state_enabled() in yaml-helper.sh.
if [ -f .factory/hooks/yaml-helper.sh ]; then
    . .factory/hooks/yaml-helper.sh
    session_state_enabled || exit 0
fi

INPUT=$(cat)

# An empty agent_type is not a Game Studios spawn, so this hook skips it. The
# port has not verified which Factory-internal agents send one. log-agent.sh
# skips them too. A MISSING agent_type is different and still logs as "unknown"
# below.
if printf '%s' "$INPUT" | grep -qE '"agent_type"[[:space:]]*:[[:space:]]*""'; then
    exit 0
fi

# Parse agent name -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null)
else
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
# OUTSIDE the branch, like SESSION_ID below. jq's `// "unknown"` substitutes for
# null and false but NOT for an empty string, so the jq path could emit a record
# with no agent name at all while the grep path guarded against it. One guard,
# both paths.
[ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"

# Parse session id -- keeps the completion record in the same three-field shape
# as log-agent.sh so both sides of a spawn belong to an identifiable session.
if command -v jq >/dev/null 2>&1; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
else
    SESSION_ID=$(echo "$INPUT" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"session_id"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_DIR="production/session-logs"

mkdir -p "$SESSION_LOG_DIR" 2>/dev/null

echo "$TIMESTAMP | $SESSION_ID | Agent completed: $AGENT_NAME" >> "$SESSION_LOG_DIR/agent-audit.log" 2>/dev/null

exit 0
