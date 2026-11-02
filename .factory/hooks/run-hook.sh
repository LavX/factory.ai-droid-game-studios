#!/usr/bin/env bash
# run-hook.sh: runs one Game Studios hook script on a payload rewritten to the
# shape the scripts expect.
#
# Factory Droid names the write tool Create and the shell tool Execute, uses
# old_str, new_str, and change_all for Edit, and sends no agent_type. The Game
# Studios scripts were written for the upstream runtime, so this adapter
# translates the payload and runs the script with it on stdin. It also handles
# droid sessions.
#
# Factory's public hook docs do not list the Edit fields old_str, new_str and
# change_all, or the Grep fields pattern and path. The adapter passes a payload
# through unchanged when a field is not one it rewrites.
#
# Called from .factory/hooks.json:
#   bash "$FACTORY_PROJECT_DIR/.factory/hooks/run-hook.sh" <script>.sh
#
# Droid sessions. A SessionStart payload that has calling_session_id belongs to a
# droid started by the main session. Session hooks (recovery block, gap check,
# session log) run for the main session only, so they are skipped for droids and
# their Stop events are skipped too.
#
# Droid identity. A Task call records description -> subagent_type. The
# SubagentStop with the same task_name gets agent_type, so the agent audit log
# names the droid. Factory payloads carry no identity for tool calls made inside
# a droid, so the per-droid rules in validate-write.sh do not apply there.
#
# Exit codes and stderr come from the script, except that the adapter exits 2 itself when
# the payload cannot be read, when jq is present and the payload is not one JSON object (an
# empty payload is not one), when a field it reads cannot be read, when the session id cannot
# be filtered, when a rewrite fails, or when its own directory cannot be found. Factory's hook
# docs give exit 2 an effect that depends on the event: it blocks a PreToolUse tool call and a
# UserPromptSubmit prompt, feeds stderr back to Droid on PostToolUse and Stop, and shows stderr
# to the user on the other events.
#
# Each jq read below ends in tr -d '\r'. A native Windows jq.exe ends every line
# with CR, and a CR would break the string comparisons.

set -u

hook_dir="$(dirname "${BASH_SOURCE[0]}")" && HERE="$(cd "$hook_dir" && pwd)" || {
  echo "run-hook: the hook directory could not be found, so the hook exits 2." >&2
  exit 2
}
script="${1:-}"
if [ -z "$script" ] || [ ! -f "$HERE/$script" ]; then
  echo "run-hook: no such hook script: ${script:-(none)}" >&2
  exit 1
fi
shift

# A read that fails stops the hook, so a partial payload never reaches the script.
payload="$(cat)" || {
  echo "run-hook: the hook payload could not be read, so the hook exits 2." >&2
  exit 2
}
state="${TMPDIR:-/tmp}/ccgs-factory-hooks"

# set_field <jq args...>: applies a jq filter to $payload and replaces the payload with the
# result. A rewrite that fails, or prints nothing, exits 2 before the script runs, so the hook
# never runs on a payload that was not rewritten. pipefail makes jq's status count, since the
# status of tr alone would hide a failed jq.
set_field() {
  local out
  out="$(set -o pipefail; printf '%s' "$payload" | jq -c "$@" 2>/dev/null | tr -d '\r')" && [ -n "$out" ] || {
    echo "run-hook: the hook payload could not be rewritten, so the hook exits 2." >&2
    exit 2
  }
  payload="$out"
}

# read_field <jq filter>: sets FIELD to one string field of $payload, with CRs removed. An absent
# field reads as empty. A read that fails exits 2 before the script runs, as set_field does.
# pipefail makes jq's status count, so tr does not hide a failed jq. Call read_field directly, not
# inside $( ), because the exit must stop the hook.
read_field() {
  FIELD="$(set -o pipefail; printf '%s' "$payload" | jq -r "$1" 2>/dev/null | tr -d '\r')" || {
    echo "run-hook: a field of the hook payload could not be read, so the hook exits 2." >&2
    exit 2
  }
}

if command -v jq >/dev/null 2>&1; then
  # The whole input must be one JSON object, so an empty input fails this check too. jq prints the
  # rewrite of the first object before it fails on trailing data, so this check reads the complete
  # input before any rewrite.
  if ! printf '%s' "$payload" | jq -es 'length == 1 and (.[0] | type == "object")' >/dev/null 2>&1; then
    echo "run-hook: the hook payload is not one JSON object, so the hook exits 2." >&2
    exit 2
  fi
  read_field '.hook_event_name // empty'
  event="$FIELD"
  read_field '.session_id // empty'
  session="$(set -o pipefail; printf '%s' "$FIELD" | tr -cd 'A-Za-z0-9_-')" || {
    echo "run-hook: the session id could not be filtered, so the hook exits 2." >&2
    exit 2
  }
  read_field '.tool_name // empty'
  tool="$FIELD"

  case "$event" in
    SessionStart)
      read_field '.calling_session_id // empty'
      caller="$FIELD"
      if [ -n "$caller" ]; then
        mkdir -p "$state" 2>/dev/null && : > "$state/droid-$session" 2>/dev/null
        exit 0
      fi
      ;;
    Stop)
      [ -f "$state/droid-$session" ] && exit 0
      ;;
    PreToolUse)
      if [ "$tool" = Task ]; then
        # The ? reads a tool input that is not an object as empty, as before. A failed field-read
        # pipeline stops the hook.
        read_field '.tool_input.subagent_type? // empty'
        type="$(printf '%s' "$FIELD" | tr -d '\t\r\n')"
        read_field '.tool_input.description? // empty'
        desc="$(printf '%s' "$FIELD" | tr -d '\t\r\n')"
        if [ -n "$type" ]; then
          mkdir -p "$state" 2>/dev/null && printf '%s\t%s\n' "$type" "$desc" >> "$state/tasks-$session" 2>/dev/null
          set_field --arg t "$type" '. + {agent_type: $t}'
        fi
      fi
      ;;
    SubagentStop)
      read_field '.task_name // empty'
      desc="$FIELD"
      map="$state/tasks-$session"
      if [ -n "$desc" ] && [ -f "$map" ]; then
        type="$(CCGS_DESC="$desc" awk -F '\t' '$2 == ENVIRON["CCGS_DESC"] { t = $1 } END { print t }' "$map")"
        [ -n "$type" ] && set_field --arg t "$type" '. + {agent_type: $t}'
      fi
      ;;
  esac

  set_field '
    def upstream_tool: if . == "Create" then "Write" elif . == "Execute" then "Bash" else . end;
    .tool_name |= (if type == "string" then upstream_tool else . end)
    | if (.tool_input | type) == "object" then
        .tool_input |= (
          if has("old_str") and (has("old_string") | not) then . + {old_string: .old_str} else . end
          | if has("new_str") and (has("new_string") | not) then . + {new_string: .new_str} else . end
          | if has("change_all") and (has("replace_all") | not) then . + {replace_all: .change_all} else . end
        )
      else . end
  '
else
  payload="$(set -o pipefail; printf '%s' "$payload" | sed \
    -e 's/"tool_name"[[:space:]]*:[[:space:]]*"Create"/"tool_name":"Write"/' \
    -e 's/"tool_name"[[:space:]]*:[[:space:]]*"Execute"/"tool_name":"Bash"/' \
    -e 's/"old_str"[[:space:]]*:/"old_string":/' \
    -e 's/"new_str"[[:space:]]*:/"new_string":/' \
    -e 's/"change_all"[[:space:]]*:/"replace_all":/')" || {
    echo "run-hook: the hook payload could not be rewritten, so the hook exits 2." >&2
    exit 2
  }
fi

printf '%s' "$payload" | bash "$HERE/$script" "$@"
exit $?
