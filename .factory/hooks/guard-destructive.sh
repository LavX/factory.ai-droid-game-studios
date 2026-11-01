#!/usr/bin/env bash
# guard-destructive.sh: blocks destructive commands, and reads, writes and edits of .env
# files and of .uasset and .umap files, which the upstream deny list covered.
#
# Blocked commands:
# - rm with recursive and force flags in any order: short clusters (-rf, -Rf, -fr,
#   -{r,f}), GNU long-option prefixes (--recurs, --forc), and PowerShell -Recurse and
#   -Force in any case or by an unambiguous prefix (-rec, -fo). A PowerShell word such
#   as -literalpath or -filter is not read as a short cluster.
# - del, erase, rd, rmdir, ri and Remove-Item with -Recurse or -r (any case or prefix).
# - git reset --hard (also --ha), force pushes (-f, --force, --mirror, +ref), and git
#   clean with -f or --force (also --f).
# - sudo.
# - chmod 777 with any number of leading zeros, and a leading setuid, setgid or sticky digit
#   (1 to 7), such as 1777, 3777, 5777, 6777 and 7777.
# - A shell that reads its commands from stdin: sh, bash, zsh, dash, ksh or ash with no
#   -c and no script operand, and bash -s. A pipe into powershell, pwsh or cmd with no
#   command switch. at or batch fed by a pipe or a here-string, with no -f.
# - A command word with an unquoted glob (*, ?, [), such as [r]m or ./run-*.sh. Brace groups
#   are expanded in every word of a command before the checks run, so {rm,-rf,x},
#   r{m,} -rf x, rm --{recursive,force} x, chmod {7,6}77 x and r{m..m} -rf x are blocked,
#   and {echo,hi} is allowed. Sequences such as {a..e} and {1..9..2}, with an optional step,
#   expand as the shell expands them. Nested groups are expanded too, so r{m,{x,y}} -rf x is
#   blocked. A quoted brace or comma, as in "{rm,x}", is literal and is not expanded. A word
#   that expands to more than 4096 words, a command whose words expand to more than 4096 words
#   in all, and a brace word that needs more than 10000 steps to scan, are blocked as too
#   complex.
# - .env files: file commands that name one (cat, head, grep, sed, cp, tar, openssl,
#   nvim, xz, split, certutil, ln and the others on the list), PowerShell Get-Content,
#   Set-Content, Add-Content and Out-File, git arguments such as HEAD:.env, find with
#   -name, -iname, -path or -ipath naming .env and with -exec, -execdir, -ok, -okdir or a
#   pipe, and Read, Create, Edit and Grep calls whose path
#   names .env. A glob or bracket pattern counts as .env when it can match one of these names:
#   .env, .envrc, .env.local, .env.example, .env.production, .env.development, .env.test or
#   .env.staging. In a shell word the leading dot has to be literal or in brackets, as in the
#   shell, so .e*, .?nv, [.]env and .[e]nv.local count, and *env and ?env do not. In find
#   -name, -iname, -path and -ipath, and in the PowerShell commands, a leading * or ? also
#   matches the dot, so find . -name '*' -exec cat {} + counts. A brace group is expanded
#   first, so .{env,x} counts.
# - .uasset and .umap files, for Write, Create and Edit calls (run-hook.sh maps Create to Write).
# - File names are checked after trailing dots and spaces are removed and a colon suffix
#   such as ::$DATA is dropped, so .env., .env::$DATA and Foo.uasset. are blocked.
#
# Coverage: shell text is parsed, not matched as a string. A # that starts a word is a
# comment and runs to the end of the line. A # after an escaped character, as in \ #, is
# part of the word. Heredoc bodies (<< and <<-) are checked line by line as commands, and
# the terminator line is not checked. The delimiter is decoded as the shell decodes it, so
# $'EOF' is EOF. A body with a quoted delimiter (any quoting, including $'...') is read with
# the quote rules. A body with an unquoted delimiter is read with quotes and << as plain text,
# since the shell runs $( ) and backticks there whatever the quotes are. Inside a $( ) or a
# backtick, the body is read as shell text again, so its quotes, # and << count. Quotes, $'...', $(...) and
# backticks are followed, and redirect targets are checked as file names. A $( ) ends at the )
# that matches its own (, so nested subshells are followed. $(( )) with no $( or backtick is kept as text.
# A Bash command is read twice, with backslashes resolved and kept, so Windows paths such
# as C:\repo\.env are checked too. The second read is skipped when the command has no
# backslash, since both reads then give the same result. NUL bytes are removed from the
# input, and CR and NUL are stripped from the jq output, so a native Windows jq.exe works.
# A $'...' string is cut at a decoded NUL (\0, \x00, \000, \400, \c@ or \c`), as bash cuts
# it, so the text after the NUL is read only to find the closing quote.
#
# Wrappers are skipped, each with its own value options, in short and GNU long forms:
# env, command, exec, nohup, nice, timeout, time, xargs, stdbuf, setsid, ionice, busybox,
# wsl, unbuffer, chrt, taskset, coproc, su, doas, pkexec, runuser, watch, flock, script,
# strace, chroot, parallel, setarch, eatmydata, systemd-run and unshare. Every value of -c
# or --command for su, runuser, flock and script is checked as shell text, also after an operand,
# and the operands of watch and parallel are checked as shell text. coproc NAME { ... } skips NAME. env -S,
# env -iS and env --split-string are checked as commands, and so is the action of trap,
# after an optional --. The operands of iex and Invoke-Expression are checked as command
# text. sh -c, bash -c, cmd /c, cmd /k, cmd /r, eval, powershell -Command, find -exec and
# the -c value of fish, rbash, mksh, csh, tcsh and ksh93 are checked as commands. A
# powershell or pwsh with no command switch and no -File has its operands checked as
# command text, after switches such as -NoProfile, -NonInteractive, -NoLogo and
# -ExecutionPolicy VALUE. function NAME { ... } checks its body. bash --rcfile and
# --init-file take a file as the next word, which is not a script operand. bash --help,
# --version and the same options of sh are allowed. File commands and git arguments
# are checked for .env names as described above. tar also checks the name that f takes
# from its option cluster, as in -f.env and -cf.env. A pattern given by -e, -f or a long
# option in grep, egrep, fgrep, rg, sed or awk, no operand is skipped as the pattern. The
# long options take the prefixes that GNU getopt_long accepts when they are unambiguous: for
# grep, --reg to --regexp and --file in full; for sed, --e to --expression and --fi to --file.
# In grep, --re, --f and --fi are ambiguous, so they are not read as pattern options. In sed,
# --f is ambiguous with --follow-symlinks, but --fi is not, so sed reads it as --file.
#
# Documented limits, not checked: variables, ${IFS}, aliases, functions called by name,
# command substitution output and words built at run time; brace groups with stray }
# characters, where the shell expands in a few cases the guard does not match, such as
# {}{}x,}; interpreters (python -c,
# node -e, perl, ruby, awk system()); PowerShell .NET calls such as [IO.File]::ReadAllText,
# -EncodedCommand, and iex or Invoke-Expression with a string built at run time;
# commands run on another machine by ssh; readers, editors and launchers outside the
# lists, such as notepad, xdg-open, curl and nc; wrappers outside the lists, such as
# fakeroot, nsenter, bwrap, firejail, tmux and screen; attached option values that name a
# file, except tar -f, such as sort -o.env; a glob or bracket name for a .env file
# that is not one of the probe names, such as .[e]nv.custom; deleting a .env file with rm, del or
# find -delete (rm .env is not blocked); rm -rF (not a deletion, since GNU and BSD rm reject
# -F); cmd and PowerShell recursive deletes such as rd /s and del /s; \u and \U
# escapes inside $'...'; Grep calls on folders, which can show .env text; Glob, LS,
# ApplyPatch and MultiEdit calls (MultiEdit is not in Factory's hook docs); files that a
# script reads. A command over the budgets below is blocked rather than checked. Inside
# double quotes, a ) that closes a case pattern in
# $( ) ends the substitution early, so a command after a later ; is read as quoted:
# "$(case x in x) echo;; esac; sudo id)" is not blocked. Options with a separate value
# are skipped only when they are in the wrapper_value list, or they are --rcfile or
# --init-file of a shell, so a value option missing from those lists hides the word after it.
#
# Known false positives, kept on purpose: a heredoc body line that begins with a blocked
# command; a name that starts with .env, such as docs/.environment.md, and a commit
# message that starts with .envrc, such as git commit -m ".envrc added"; git push
# --dry-run --force; a backslash inside a path, such as cat docs\.env; text after a
# backslash-escaped dollar, such as echo \$(rm -rf x); a command word with a glob, such as
# ./run-*.sh; a value given by -e or -f, which is checked as a file, so grep -e .env docs is
# blocked; a find -name glob that can match .env, such as '*.*' or '*', when the command has a
# pipe, as find . -name '*.*' -print | sort; and a $( ) or backtick in a heredoc body with a
# quoted delimiter, outside single quotes, since the body is checked as commands, as in
# cat <<"EOF" with $(sudo id) in the body. rm .env is not blocked (a limit, not a false
# positive). Also kept on purpose: words after the user of su, or after the file of flock, when
# a -c value came first, such as su -c 'echo ok' root rm -rf x, which are read as commands, as
# they are without -c.
#
# Budgets, blocked as too large to check: more than 256 KB of shell text in one command, counted
# in bytes, with nested text and both passes counted; more than 5000 simple-command checks, where a
# text with a backslash is parsed twice, so its commands count twice; or a check still running after
# 15 seconds, which keeps the guard's own work inside the 30-second hook timeout. A stalled external
# command, such as jq or tr, delays that stop until it returns. Nested wrappers such as watch cost
# more than their text, so the time limit is the bound that holds for them.
#
# run-hook.sh renames Factory's Execute and Create tools to Bash and Write before this
# script sees them. The guard also accepts Execute and Create, so a call that reaches it
# unrenamed is checked the same way. Exit 2 blocks the call and writes the reason to stderr.
# Exit 0 allows it. Needs jq. Without jq the guard allows the call, and the permissionRules in
# .factory/settings.json still apply. With jq, a payload that cannot be read, or is not one tool
# call with a tool name, is blocked. run-hook.sh also exits 2 when its directory cannot be found,
# the payload cannot be read, or a rewrite fails. With jq it also exits 2 for a payload that is
# empty or is not one JSON object, a field it cannot read, or a session id it cannot filter.
# test-guard.sh holds the regression
# cases.

command -v jq >/dev/null 2>&1 || exit 0

# No set -u: bash 3.2, the macOS default, reports an empty array as unbound.

# Markers for a quoted { } or , inside a word, so brace expansion does not split a quoted word.
# check_text turns them back into braces and commas before it parses shell text.
MK_OPEN=$'\001'
MK_CLOSE=$'\002'
MK_COMMA=$'\003'

# Budgets for one hook run, counted in check_text and check_words. Every text is counted in bytes,
# nested ones and both passes included: more than 256 KB of shell text, or more than 5000
# simple-command checks, is too large to check. A check that is still running after 15 seconds is
# blocked too, since the cost of nested wrappers grows faster than the text, and the guard must
# return before the 30-second hook timeout in hooks.json. The watchdog below applies the same limit
# inside the parser, which can run long between two checks.
WORK_BYTES=0
WORK_CMDS=0
BYTE_COUNT=0

block() {
  echo "Blocked by the CCGS destructive-command guard: $1. This command is blocked by this guard. If the step is intended, ask the user to run it outside the agent." >&2
  exit 2
}

# The watchdog blocks a check that is still running after 15 seconds, including inside a parser
# loop that the check functions do not reach. It starts before the payload is read. A background
# job sends TERM to this shell after 15 seconds, and the trap blocks the call. If sleep fails, the
# job sends USR1 at once, and that trap blocks the call too, so a missing timer fails closed. The
# EXIT trap stops the job when the hook ends first. The job's stdin and output are /dev/null, so it
# does not hold the hook's pipes open. Bash runs a trap only after a foreground command returns, so
# a stalled external command, such as jq or tr, delays the block until it returns.
GUARD_WATCHDOG=""
trap 'block "the check ran longer than 15 seconds, too long to check"' TERM
trap 'block "the time limit could not start, so the check is blocked"' USR1
trap 'if [ -n "$GUARD_WATCHDOG" ]; then kill "$GUARD_WATCHDOG" 2>/dev/null; fi' EXIT
( sleep 15 && kill -TERM "$$" || kill -USR1 "$$" ) </dev/null >/dev/null 2>&1 &
GUARD_WATCHDOG=$!

# tr -d: a native Windows jq.exe ends each line with CR, which would break the match. A NUL
# byte would make bash drop text and print a warning, so NUL bytes are removed too. Bytes 1 to 3
# are removed as well, since shell_words uses them as markers for quoted braces and commas. A
# name that loses them can only match more, so the change blocks more, never less.
# pipefail makes a failed cat or tr fail the read. A failed read blocks the call, so a partial
# payload never passes.
input="$(set -o pipefail; cat | tr -d '\000-\003')" || block "the hook payload could not be read"

# A payload must be one JSON object with a non-empty string tool_name. Any other payload, such as
# an empty or truncated one, cannot be checked, so the call is blocked. pipefail makes a failed jq
# fail the substitution, so tr does not hide it.
printf '%s' "$input" | jq -es 'length == 1 and (.[0] | type == "object") and ((.[0].tool_name | type) == "string") and (.[0].tool_name != "")' >/dev/null 2>&1 || block "the hook payload is not one tool call with a tool name, so the call cannot be checked"
tool="$(set -o pipefail; printf '%s' "$input" | jq -r '.tool_name' 2>/dev/null | tr -d '\r\000')" || block "the tool name could not be read from the hook payload"

# has_flag <glob-class> <args...>: a short flag such as -xyz holds a character in the class.
has_flag() {
  local cls="$1" t
  shift
  for t in "$@"; do
    case "$t" in
      --*) ;;
      -*) case "$t" in -*$cls*) return 0 ;; esac ;;
    esac
  done
  return 1
}

# has_long <name> <args...>: a long flag, bare or with =value.
has_long() {
  local want="$1" t
  shift
  for t in "$@"; do
    case "$t" in
      "$want" | "$want="*) return 0 ;;
    esac
  done
  return 1
}

# has_long_prefix <letter> <args...>: a GNU long option that starts with --<letter>, such
# as --r or --recurs for rm --recursive. For rm, --r and --f name only one option each.
has_long_prefix() {
  local l="$1" t
  shift
  for t in "$@"; do
    case "$t" in
      "--$l"*) return 0 ;;
    esac
  done
  return 1
}

# wrapper_value <wrapper> <option>: returns 0 when the option takes its value as the next
# word. The value options belong to one wrapper, so -c means something else elsewhere.
wrapper_value() {
  case "$1 $2" in
    'env -u' | 'env -C' | 'env -a' | 'env --unset' | 'env --chdir' | 'env --argv0' \
    | 'nice -n' | 'nice --adjustment' \
    | 'timeout -s' | 'timeout -k' | 'timeout --signal' | 'timeout --kill-after' \
    | 'exec -a' \
    | 'time -f' | 'time -o' | 'time --format' | 'time --output' \
    | 'stdbuf -i' | 'stdbuf -o' | 'stdbuf -e' \
    | 'stdbuf --input' | 'stdbuf --output' | 'stdbuf --error' \
    | 'ionice -c' | 'ionice -n' | 'ionice -p' | 'ionice -P' | 'ionice -u' \
    | 'ionice --class' | 'ionice --classdata' \
    | 'wsl -d' | 'wsl -u' | 'wsl --cd' | 'wsl --distribution' | 'wsl --user' | 'wsl --shell-type' \
    | 'xargs -I' | 'xargs -P' | 'xargs -L' | 'xargs -d' | 'xargs -E' | 'xargs -a' \
    | 'xargs -n' | 'xargs -s' | 'xargs --arg-file' | 'xargs --delimiter' | 'xargs --max-args' \
    | 'xargs --max-procs' | 'xargs --max-chars' | 'xargs --process-slot-var' \
    | 'xargs --max-lines' \
    | 'chrt -T' | 'chrt -P' | 'chrt -D' | 'chrt --sched-runtime' | 'chrt --sched-period' \
    | 'chrt --sched-deadline')
      return 0
      ;;
    'su -s' | 'su --shell' | 'su -g' | 'su --group' | 'su -G' | 'su --supp-group' \
    | 'su -w' | 'su --whitelist-environment' \
    | 'runuser -u' | 'runuser --user' | 'runuser -g' | 'runuser --group' \
    | 'runuser -G' | 'runuser --supp-group' | 'runuser -s' | 'runuser --shell' \
    | 'doas -u' | 'doas -C' | 'pkexec --user' \
    | 'watch -n' | 'watch --interval' \
    | 'flock -w' | 'flock --timeout' | 'flock -E' | 'flock --conflict-exit-code' \
    | 'strace -o' | 'strace -e' | 'strace -p' | 'strace -s' | 'strace -a' | 'strace -E' \
    | 'strace -u' | 'strace -I' | 'strace -O' | 'strace -P' | 'strace -X' | 'strace -S' \
    | 'strace -b' \
    | 'parallel -j' | 'parallel --jobs' | 'parallel -S' | 'parallel --sshlogin' \
    | 'parallel -a' | 'parallel --arg-file' | 'parallel -I' | 'parallel --colsep' \
    | 'systemd-run -p' | 'systemd-run --property' | 'systemd-run -u' | 'systemd-run --unit' \
    | 'systemd-run --slice' | 'systemd-run --description' | 'systemd-run --uid' \
    | 'systemd-run --gid' | 'systemd-run -E' | 'systemd-run --setenv' \
    | 'unshare -S' | 'unshare --setuid' | 'unshare -G' | 'unshare --setgid' \
    | 'unshare -R' | 'unshare --root' | 'unshare -w' | 'unshare --wd' \
    | 'unshare --map-user' | 'unshare --map-group' | 'unshare --propagation')
      return 0
      ;;
  esac
  return 1
}

# wrap_text_opt <wrapper> <word>: returns 0 when the word is the option whose value is shell
# text, such as su -c, runuser --command, flock -c or script -qc. WT_NEXT is 1 when the text
# is the next word, and 0 when it is attached to the option, as in --command=TEXT, -cTEXT or
# -lcTEXT. In a short cluster, c is the command option only when no letter before it takes a
# value, since getopt gives the rest of the word to such a letter. vals lists those letters.
wrap_text_opt() {
  local w="$2" k c vals lg is_cmd full
  WT_NEXT=0
  WT_VAL=""
  case "$1" in
    su) vals=gGsw ;;
    runuser) vals=ugGsw ;;
    flock) vals=Ew ;;
    script) vals=BEIOoTt ;;
    *) return 1 ;;
  esac
  case "$w" in
    --command) WT_NEXT=1; return 0 ;;
    --command=*) WT_VAL="${w#--command=}"; return 0 ;;
    --*)
      # GNU getopt_long takes any unambiguous prefix of a long option, so --comm and
      # --session-com name the command option. Ambiguous prefixes such as --c or --s are read
      # as the command option too. That over-blocks only those forms, which getopt rejects or
      # which name that option.
      lg="${w#--}"
      lg="${lg%%=*}"
      is_cmd=0
      for full in command session-command; do
        case "$full" in "$lg"*) is_cmd=1 ;; esac
      done
      if [ -z "$lg" ] || [ "$is_cmd" = 0 ]; then return 1; fi
      case "$w" in
        *=*) WT_VAL="${w#*=}" ;;
        *) WT_NEXT=1 ;;
      esac
      return 0
      ;;
    -?*) ;;
    *) return 1 ;;
  esac
  for ((k = 1; k < ${#w}; k++)); do
    c="${w:k:1}"
    if [ "$c" = c ]; then
      if [ "$((k + 1))" -lt "${#w}" ]; then WT_VAL="${w:k+1}"; else WT_NEXT=1; fi
      return 0
    fi
    case "$vals" in *"$c"*) return 1 ;; esac
  done
  return 1
}

# env_split <word>: returns 0 when the word is an env option cluster that has S, such as -iS
# or -vS"...", and sets SPLIT_REST to the text after the S. -u, -C and -a take a value, so an
# S after one of them belongs to that value.
env_split() {
  local w="$1" k=1 c
  case "$w" in
    -[!-]*) ;;
    *) return 1 ;;
  esac
  while [ "$k" -lt "${#w}" ]; do
    c="${w:k:1}"
    case "$c" in
      S) SPLIT_REST="${w:k+1}"; return 0 ;;
      u | C | a) return 1 ;;
    esac
    k=$((k + 1))
  done
  return 1
}

# base_name <path>: sets NAME to the last component of the path, in lowercase. Both /
# and \ separate components, so C:\repo\.env and ./.env both give .env. A variable is
# set instead of printed, so the check runs without a subshell on bash 4 and later. On bash
# 3.2, tr lowercases the name, and a failed tr blocks the call rather than leave NAME empty.
base_name() {
  local p="${1//\\//}"
  p="${p##*/}"
  if [ "${BASH_VERSINFO[0]:-3}" -ge 4 ]; then
    NAME="${p,,}"
  else
    NAME="$(set -o pipefail; printf '%s' "$p" | tr '[:upper:]' '[:lower:]')" || block "the file name could not be lowercased"
  fi
}

# env_name [1]: after base_name, returns 0 when NAME is a .env file, or a glob or bracket pattern
# that can match one of the probe names below, such as .e*, .?nv, [.]env or .[e]nv.local. With
# no argument, the pattern is a shell word, so its leading dot has to be literal or in brackets,
# as the shell expands it: *env does not count. With 1, the pattern is matched as find -name
# and PowerShell names are, where a leading * or ? also matches the dot.
env_name() {
  local any="${1:-0}" p
  case "$NAME" in
    .env*) return 0 ;;
    *\** | *\?* | *\[*) ;;
    *) return 1 ;;
  esac
  if [ "$any" = 0 ]; then
    case "$NAME" in
      '.'* | '['*) ;;
      *) return 1 ;;
    esac
  fi
  for p in .env .envrc .env.local .env.example .env.production \
    .env.development .env.test .env.staging; do
    # shellcheck disable=SC2053
    if [[ $p == $NAME ]]; then return 0; fi
  done
  return 1
}

# env_check <command> <word> [1]: blocks when the base name of the word is a .env file. The
# optional 1 matches the pattern as find and PowerShell do (see env_name).
env_check() {
  base_name "$2"
  if env_name "${3:-0}"; then block "a .env file given to $1"; fi
}

# env_block <command> <word> [1]: like env_check, but a {a,b} group, nested groups and sequences
# included, is expanded first, the way the shell expands it, and each resulting word is checked.
env_block() {
  local w="$2" t
  if brace_words "$w"; then
    for t in "${BW[@]}"; do env_check "$1" "$t" "${3:-0}"; done
  else
    env_check "$1" "$w" "${3:-0}"
  fi
  return 0
}

# long_is <word> <option> <min>: returns 0 when the word is a long option, with an optional
# =VALUE, whose name is at least min letters and is a prefix of the option's full name. The
# minimum is the shortest prefix that is unambiguous for the tool, so it is not a guess.
long_is() {
  local w="${1%%=*}"
  case "$w" in --?*) ;; *) return 1 ;; esac
  w="${w#--}"
  [ "${#w}" -ge "$3" ] && [[ "$2" == "$w"* ]]
}

# cmd_name <word>: sets CMD to the command a word runs, without a .exe suffix.
cmd_name() {
  base_name "$1"
  CMD="${NAME%.exe}"
}

# is_word_start <char>: returns 0 when a # after this character starts a comment. The
# empty string stands for the start of the text.
is_word_start() {
  case "$1" in
    '' | ' ' | $'\t' | $'\n' | ';' | '&' | '|' | '(' | ')') return 0 ;;
  esac
  return 1
}

# arith_end <start>: start is the index of the $ of a $(( )) expansion in split_commands, and
# the characters cs and their count n are read from that function. When the expansion has no
# $( and no backtick inside it, sets AEND to the index of its last ) and returns 0. Otherwise
# returns 1, and the text is split as a command substitution.
arith_end() {
  local start="$1" k depth=2 c
  k=$((start + 3))
  while [ "$k" -lt "$n" ]; do
    c="${cs[k]}"
    case "$c" in
      '(') depth=$((depth + 1)) ;;
      ')')
        depth=$((depth - 1))
        if [ "$depth" -eq 0 ]; then AEND=$k; return 0; fi
        ;;
      '`') return 1 ;;
      '$') if [ "${cs[k+1]}" = '(' ]; then return 1; fi ;;
    esac
    k=$((k + 1))
  done
  return 1
}

# split_commands <text> [noq]: appends one record per simple command to the array SC_REC, in
# order, and a | record after a command that a pipe follows. It does not clear SC_REC, so nested
# calls add to it. It splits at ; ( ) | and at & that is not part of a redirect, and at newlines
# outside quotes. It also splits at $( and backticks, even inside double quotes, where the shell
# runs them. The quote state is saved in sq and the nesting kind in sk for each $( or
# backtick, and restored when it closes. In $'...' a backslash escapes the next
# character, so \' does not end the string. A # that starts a word is a comment: it is
# dropped up to the end of the line. After << or <<- the delimiter is recorded in hd, decoded
# as the shell decodes it, with its quotedness in hn: 1 when no part of it is quoted. At the
# next unquoted newline the body lines are read up to each terminator. Each body line is split
# on its own, with a fresh quote state, and the terminator is not checked. In a body with an
# unquoted delimiter, noq is 1: outside $( ) and backticks, quotes, # and << are plain text, and
# $( ) and backticks are still split. Inside them the shell reads quotes, # and << as usual, so
# the flag eff is 0 there and the quote state is opened.
split_commands() {
  local s="$1" noq="${2:-0}" n i c nx pv nk top q="" cur="" j k e wd strip bs line cmp nxt bq hq ak
  local raw qd rec eff
  local pe=0 pesc=0
  local -a sq=() sk=() hd=() hx=() hn=() sd=() cs=()
  n="${#s}"
  # cs holds the characters of s, read by index below. A substring such as ${s:i:1} costs time
  # in the length of s, so s is split once here, a window of 256 characters at a time.
  local b=0 win wl plain
  while [ "$b" -lt "$n" ]; do
    win="${s:b:256}"
    wl="${#win}"
    for ((j = 0; j < wl; j++)); do cs+=("${win:j:1}"); done
    b=$((b + 256))
  done
  # The printable ASCII characters that split_commands never treats specially, plus space and tab.
  plain=$' \t!%*+,-./0123456789:=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_abcdefghijklmnopqrstuvwxyz{}~'
  i=0
  while [ "$i" -lt "$n" ]; do
    c="${cs[i]}"
    # pe is 1 when the previous character was escaped, so it is part of a word.
    pe="$pesc"
    pesc=0
    # A character in plain has no branch below in any quote state, so it is appended here.
    # This skips the branch tests for most characters.
    if [[ "$plain" == *"$c"* ]]; then
      cur+="$c"
      i=$((i + 1))
      continue
    fi
    nx="${cs[i+1]}"
    pv=""
    [ "$i" -gt 0 ] && pv="${cs[i-1]}"
    nk="${#sk[@]}"
    top=""
    [ "$nk" -gt 0 ] && top="${sk[$((nk - 1))]}"
    # eff is the noq rule outside $( ) and backticks. Inside them the text is shell text again.
    eff="$noq"
    [ "$nk" -gt 0 ] && eff=0
    if [ "$q" = A ]; then
      if [ "$c" = '\' ]; then
        cur+="$c$nx"
        i=$((i + 1))
      else
        [ "$c" = "'" ] && q=""
        cur+="$c"
      fi
    elif [ "$c" = $'\n' ] && [ -z "$q" ]; then
      SC_REC+=("$cur")
      cur=""
      # Heredoc bodies start on the next line, in the order their operators were read.
      bs=$((i + 1))
      for ((k = 0; k < ${#hd[@]}; k++)); do
        while :; do
          # The line runs to the next newline, and nxt is the index just after that newline.
          line=""
          nxt=$n
          bq=$bs
          while [ "$bq" -lt "$n" ]; do
            if [ "${cs[bq]}" = $'\n' ]; then nxt=$((bq + 1)); break; fi
            line+="${cs[bq]}"
            bq=$((bq + 1))
          done
          cmp="$line"
          if [ "${hx[k]}" = 1 ]; then
            while [ "${cmp:0:1}" = $'\t' ]; do cmp="${cmp:1}"; done
          fi
          if [ "$cmp" = "${hd[k]}" ]; then
            bs=$nxt
            break
          fi
          if [ "$bs" -ge "$n" ]; then break; fi
          split_commands "$line" "${hn[k]}"
          bs=$nxt
        done
      done
      if [ "${#hd[@]}" -gt 0 ]; then
        i=$((bs - 1))
        hd=()
        hx=()
        hn=()
      fi
    elif [ "$q" = "'" ]; then
      [ "$c" = "'" ] && q=""
      cur+="$c"
    elif [ "$c" = '\' ]; then
      [ "$nx" = $'\n' ] || cur+="$c$nx"
      [ "$nx" = $'\n' ] || pesc=1
      i=$((i + 1))
    elif [ "$c" = "'" ] && [ -z "$q" ] && [ "$eff" = 0 ]; then
      q="'"
      cur+="$c"
    elif [ "$c" = '$' ] && [ "$nx" = "'" ] && [ -z "$q" ] && [ "$eff" = 0 ]; then
      q=A
      cur+="$c$nx"
      i=$((i + 1))
    elif [ "$c" = '#' ] && [ -z "$q" ] && [ "$pe" = 0 ] && [ "$eff" = 0 ] && is_word_start "$pv"; then
      # A comment runs to the end of the line. The newline after it still splits.
      while [ "$((i + 1))" -lt "$n" ] && [ "${cs[i+1]}" != $'\n' ]; do
        i=$((i + 1))
      done
    elif [ "$c" = '<' ] && [ "$nx" = '<' ] && [ -z "$q" ] && [ "$eff" = 0 ]; then
      # In an unquoted body, << outside $( ) and backticks is text, so it is not a heredoc opener.
      if [ "${cs[i+2]}" = '<' ]; then
        # <<< is a here-string, not a heredoc.
        cur+="<<<"
        i=$((i + 2))
      else
        # Read the delimiter word after << or <<- as raw text, so its quoting is known. Then decode
        # it as the shell does, with shell_words, so $'EOF' and "EOF" both give EOF.
        j=$((i + 2))
        strip=0
        if [ "${cs[j]}" = '-' ]; then
          strip=1
          j=$((j + 1))
        fi
        while [ "${cs[j]}" = ' ' ] || [ "${cs[j]}" = $'\t' ]; do j=$((j + 1)); done
        raw=""
        qd=0
        while [ "$j" -lt "$n" ]; do
          e="${cs[j]}"
          case "$e" in
            ' ' | $'\t' | $'\n' | ';' | '&' | '|' | '(' | ')' | '<' | '>') break ;;
            "'" | '"')
              qd=1
              raw+="$e"
              j=$((j + 1))
              while [ "$j" -lt "$n" ] && [ "${cs[j]}" != "$e" ]; do
                if [ "$e" = '"' ] && [ "${cs[j]}" = '\' ]; then
                  # A backslash-newline inside double quotes is removed by bash, so it is skipped.
                  if [ "${cs[j+1]}" = $'\n' ]; then j=$((j + 2)); continue; fi
                  raw+="${cs[j]}"; j=$((j + 1))
                fi
                raw+="${cs[j]}"
                j=$((j + 1))
              done
              raw+="$e"
              ;;
            '\')
              # A backslash-newline is a line continuation, which bash removes, so the delimiter
              # stays unquoted and both characters are skipped.
              if [ "${cs[j+1]}" = $'\n' ]; then
                j=$((j + 1))
              else
                qd=1
                raw+="$e${cs[j+1]}"
                j=$((j + 1))
              fi
              ;;
            '$')
              if [ "${cs[j+1]}" = "'" ]; then
                qd=1
                raw+="\$'"
                j=$((j + 2))
                while [ "$j" -lt "$n" ] && [ "${cs[j]}" != "'" ]; do
                  if [ "${cs[j]}" = '\' ]; then raw+="${cs[j]}"; j=$((j + 1)); fi
                  raw+="${cs[j]}"
                  j=$((j + 1))
                done
                raw+="'"
              else
                raw+="$e"
              fi
              ;;
            *) raw+="$e" ;;
          esac
          j=$((j + 1))
        done
        SW_REC=()
        shell_words resolved "$raw"
        wd=""
        for rec in "${SW_REC[@]}"; do wd+="${rec:1}"; done
        # A quoted brace or comma in the delimiter is a marker from shell_words. The body lines are
        # compared with the delimiter as they are, so the markers become the characters they stand for.
        wd="${wd//$MK_OPEN/\{}"
        wd="${wd//$MK_CLOSE/\}}"
        wd="${wd//$MK_COMMA/,}"
        SW_REC=()
        for ((hq = i; hq < j; hq++)); do cur+="${cs[hq]}"; done
        i=$((j - 1))
        hd+=("$wd")
        hx+=("$strip")
        hn+=("$((1 - qd))")
      fi
    elif [ "$c" = '"' ] && [ "$eff" = 0 ]; then
      if [ "$q" = '"' ]; then q=""; else q='"'; fi
      cur+="$c"
    elif [ "$c" = '$' ] && [ "$nx" = '(' ] && [ "${cs[i+2]}" = '(' ] && [ "$q" != "'" ] && [ "$q" != A ] && arith_end "$i"; then
      # $(( )) is arithmetic and runs no command, so it is kept as text and not split.
      for ((ak = i; ak <= AEND; ak++)); do cur+="${cs[ak]}"; done
      i=$AEND
    elif [ "$c" = '$' ] && [ "$nx" = '(' ]; then
      SC_REC+=("$cur")
      cur=""
      sq+=("$q")
      sk+=("(")
      sd+=(0)
      q=""
      i=$((i + 1))
    elif [ "$c" = '`' ] && [ "$top" = '`' ]; then
      SC_REC+=("$cur")
      cur=""
      q="${sq[$((nk - 1))]}"
      unset "sq[$((nk - 1))]" "sk[$((nk - 1))]" "sd[$((nk - 1))]"
    elif [ "$c" = '`' ]; then
      SC_REC+=("$cur")
      cur=""
      sq+=("$q")
      sk+=('`')
      sd+=(0)
      q=""
    elif [ "$c" = '(' ] && [ "$top" = '(' ] && [ -z "$q" ]; then
      # A ( inside $( ) opens a level. Its ) closes the level, not the substitution.
      sd[$((nk - 1))]=$((sd[nk - 1] + 1))
      SC_REC+=("$cur")
      cur=""
    elif [ "$c" = ')' ] && [ "$top" = '(' ] && [ -z "$q" ] && [ "${sd[$((nk - 1))]}" -gt 0 ]; then
      sd[$((nk - 1))]=$((sd[nk - 1] - 1))
      SC_REC+=("$cur")
      cur=""
    elif [ "$c" = ')' ] && [ "$top" = '(' ] && [ -z "$q" ]; then
      SC_REC+=("$cur")
      cur=""
      q="${sq[$((nk - 1))]}"
      unset "sq[$((nk - 1))]" "sk[$((nk - 1))]" "sd[$((nk - 1))]"
    elif [ -z "$q" ] && [ "$c" = '&' ] && { [ "$pv" = '>' ] || [ "$pv" = '<' ] || [ "$nx" = '>' ]; }; then
      cur+="$c"
    elif [ -z "$q" ] && [ "$c" = '|' ] && [ "$pv" = '>' ]; then
      cur+="$c"
    elif [ -z "$q" ] && [ "$c" = '|' ] && [ "$nx" = '|' ]; then
      # || is an OR list, not a pipe, so it is split without a pipe marker.
      SC_REC+=("$cur")
      cur=""
      i=$((i + 1))
    elif [ -z "$q" ] && [ "$c" = '|' ]; then
      # A pipe is split, and the | record after the command marks what follows as fed by it.
      SC_REC+=("$cur" "|")
      cur=""
    elif [ -z "$q" ] && { [ "$c" = ';' ] || [ "$c" = '&' ] || [ "$c" = '|' ] || [ "$c" = '(' ] || [ "$c" = ')' ]; }; then
      SC_REC+=("$cur")
      cur=""
    else
      cur+="$c"
    fi
    i=$((i + 1))
  done
  SC_REC+=("$cur")
}

# emit_word: appends the word in w to SW_REC as a W record, or as an R record when it is a
# redirect target, then clears it. It uses the locals of shell_words.
emit_word() {
  if [ "$rt" = 1 ]; then
    SW_REC+=("R$w")
    rt=0
  else
    SW_REC+=("W$w")
  fi
  w=""
  have=0
}

# wq <char>: appends a quoted or escaped character to w, the word of shell_words. A brace or a
# comma is appended as a marker, so brace expansion leaves a quoted word alone. check_text turns
# the markers back into braces and commas. A decoded byte 1 to 3, such as $'\001', is dropped,
# so that only wq can make a marker.
wq() {
  case "$1" in
    '{') w+="$MK_OPEN" ;;
    '}') w+="$MK_CLOSE" ;;
    ',') w+="$MK_COMMA" ;;
    $'\001' | $'\002' | $'\003') ;;
    *) w+="$1" ;;
  esac
}

# shell_words <resolved|literal> <simple command>: appends one record per word to SW_REC.
# A record starts with W for a word, or with R for a redirect target (the word after
# < > >> and the like). The fd number before a redirect is dropped. Quotes are removed,
# and $'...' escapes are decoded. In resolved mode an unquoted backslash escapes the
# next character, as in the shell. In literal mode it stays in the word.
shell_words() {
  local mode="$1" s="$2" n i c nx e q="" w="" have=0 rt=0 j hex oct ch b win wl nul=0 nulw=""
  local -a cs=()
  n="${#s}"
  # cs holds the characters of s, read by index below. See split_commands.
  b=0
  while [ "$b" -lt "$n" ]; do
    win="${s:b:256}"
    wl="${#win}"
    for ((j = 0; j < wl; j++)); do cs+=("${win:j:1}"); done
    b=$((b + 256))
  done
  # Printable ASCII that is a word character with no quote open: not a space, tab, quote,
  # backslash, $, < or >. These take the last branch below, so they are appended here.
  local plainw=$'!%*+,-./0123456789:=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_abcdefghijklmnopqrstuvwxyz{}~'
  i=0
  while [ "$i" -lt "$n" ]; do
    c="${cs[i]}"
    if [ -z "$q" ] && { [ "$c" = ' ' ] || [ "$c" = $'\t' ]; }; then
      if [ "$have" = 1 ]; then emit_word; fi
      i=$((i + 1))
      continue
    fi
    if [ -z "$q" ] && [[ "$plainw" == *"$c"* ]]; then
      w+="$c"
      have=1
      i=$((i + 1))
      continue
    fi
    nx="${cs[i+1]}"
    if [ "$q" = A ]; then
      if [ "$c" = "'" ]; then
        q=""
        # A NUL cut the string: the words kept are those before the NUL.
        if [ "$nul" = 1 ]; then w="$nulw"; nul=0; fi
      elif [ "$c" = '\' ]; then
        i=$((i + 1))
        e="${cs[i]}"
        case "$e" in
          a) printf -v ch '\007'; w+="$ch" ;;
          b) printf -v ch '\010'; w+="$ch" ;;
          e | E) printf -v ch '\033'; w+="$ch" ;;
          f) printf -v ch '\014'; w+="$ch" ;;
          n) printf -v ch '\012'; w+="$ch" ;;
          r) printf -v ch '\015'; w+="$ch" ;;
          t) printf -v ch '\011'; w+="$ch" ;;
          v) printf -v ch '\013'; w+="$ch" ;;
          x)
            hex=""
            while [ "${#hex}" -lt 2 ] && [[ "${cs[i+1]}" =~ ^[0-9A-Fa-f]$ ]]; do
              i=$((i + 1))
              hex+="${cs[i]}"
            done
            if [ -z "$hex" ]; then
              w+='\x'
            elif [ $((16#$hex)) -eq 0 ]; then
              if [ "$nul" = 0 ]; then nulw="$w"; nul=1; fi
            else
              printf -v ch "\\x$hex"; wq "$ch"
            fi
            ;;
          [0-7])
            oct="$e"
            while [ "${#oct}" -lt 3 ] && [[ "${cs[i+1]}" =~ ^[0-7]$ ]]; do
              i=$((i + 1))
              oct+="${cs[i]}"
            done
            # A value of 256 or more wraps to 0 in bash, so \400 is a NUL too.
            if [ $((8#$oct % 256)) -eq 0 ]; then
              if [ "$nul" = 0 ]; then nulw="$w"; nul=1; fi
            else
              printf -v ch "\\$oct"
              wq "$ch"
            fi
            ;;
          c)
            # \c@, \c` and \c followed by a space are NUL, as in bash. Other \cX stays as text.
            if [ "${cs[i+1]}" = '@' ] || [ "${cs[i+1]}" = '`' ] || [ "${cs[i+1]}" = ' ' ]; then
              i=$((i + 1))
              if [ "$nul" = 0 ]; then nulw="$w"; nul=1; fi
            else
              w+='\c'
            fi
            ;;
          "'" | '"' | '\' | '?') wq "$e" ;;
          *) w+="\\"; wq "$e" ;;
        esac
      else
        wq "$c"
      fi
    elif [ "$q" = "'" ]; then
      if [ "$c" = "'" ]; then
        q=""
      else
        wq "$c"
      fi
    elif [ "$q" = '"' ]; then
      if [ "$c" = '"' ]; then
        q=""
      elif [ "$c" = '\' ]; then
        case "$nx" in
          '"' | '\' | '$' | "\`") wq "$nx"; i=$((i + 1)) ;;
          *) w+="$c" ;;
        esac
      else
        wq "$c"
      fi
    elif [ "$c" = '$' ] && [ "$nx" = "'" ]; then
      q=A
      have=1
      i=$((i + 1))
    elif [ "$c" = '$' ] && [ "$nx" = '"' ]; then
      q='"'
      have=1
      i=$((i + 1))
    elif [ "$c" = '"' ] || [ "$c" = "'" ]; then
      q="$c"
      have=1
    elif [ "$c" = '\' ]; then
      have=1
      if [ -z "$nx" ]; then
        w+="$c"
      elif [ "$mode" = literal ]; then
        w+="$c"
        wq "$nx"
        i=$((i + 1))
      else
        wq "$nx"
        i=$((i + 1))
      fi
    elif [ "$c" = '<' ] || [ "$c" = '>' ]; then
      if [ "$have" = 1 ] && [[ "$w" =~ ^[0-9]+$ ]]; then
        w=""
        have=0
      elif [ "$have" = 1 ]; then
        emit_word
      fi
      j=0
      while [ "$j" -lt 2 ]; do
        case "${cs[i+1]}" in
          '<' | '>' | '&' | '|') i=$((i + 1)); j=$((j + 1)) ;;
          *) break ;;
        esac
      done
      rt=1
    elif [ "$c" = ' ' ] || [ "$c" = $'\t' ]; then
      if [ "$have" = 1 ]; then emit_word; fi
    else
      w+="$c"
      have=1
    fi
    i=$((i + 1))
  done
  if [ "$nul" = 1 ]; then w="$nulw"; nul=0; fi
  if [ "$have" = 1 ]; then emit_word; fi
  return 0
}

# check_segment <resolved|literal> <simple command>: checks the redirect targets as file
# names, then the command.
check_segment() {
  local mode="$1" rec t
  local -a w=() r=()
  # SEG_IN is 1 when the command is fed by a pipe (FED_PIPE) or by a here-string.
  SEG_IN="$FED_PIPE"
  case "$2" in *'<<<'*) SEG_IN=1 ;; esac
  # The words are copied out of SW_REC before any nested check runs, since that reuses it.
  SW_REC=()
  shell_words "$mode" "$2"
  for rec in "${SW_REC[@]}"; do
    case "$rec" in
      W*) w+=("${rec:1}") ;;
      R*) r+=("${rec:1}") ;;
    esac
  done
  SW_REC=()
  for t in "${r[@]}"; do
    env_block "a redirect" "$t"
  done
  check_words "$mode" "${w[@]}"
}

# byte_count <text>: sets BYTE_COUNT to the length of text in bytes. ${#text} counts characters in
# a UTF-8 locale, so the length comes from wc -c under LC_ALL=C, and the parser's locale does not
# change. The count runs with pipefail, so a failed wc blocks the call, and the result must be
# digits once its spaces are removed, so a count that fails never passes. The digits are read as
# decimal, since a leading zero would make bash read octal. More than 12 digits is far over the
# budget, so it blocks the call before any arithmetic, and a huge count cannot wrap to a small one.
byte_count() {
  local n
  n="$(set -o pipefail; printf '%s' "$1" | LC_ALL=C wc -c)" || block "the shell text could not be measured"
  n="${n//[[:space:]]/}"
  case "$n" in
    '' | *[!0-9]*) block "the shell text could not be measured" ;;
  esac
  if [ "${#n}" -gt 12 ]; then block "the shell text could not be measured"; fi
  BYTE_COUNT=$((10#$n))
}

# check_text <resolved|literal> <text>: checks each simple command in the text, nested
# ones included. TXT_PIPE is 1 when the text has a pipe anywhere, and FED_PIPE is 1 for a
# command that is the target of a pipe. Both are saved and restored around each command.
check_text() {
  local mode="$1" seg k saved_t saved_f saved_s has_pipe=0 fed=0 text="$2"
  local -a segs=() feds=()
  # A quoted brace or comma in the text is a marker from shell_words. The text is shell text
  # again here, so the markers become the characters they stand for.
  text="${text//$MK_OPEN/\{}"
  text="${text//$MK_CLOSE/\}}"
  text="${text//$MK_COMMA/,}"
  byte_count "$text"
  WORK_BYTES=$((WORK_BYTES + BYTE_COUNT))
  if [ "$WORK_BYTES" -gt 262144 ]; then block "shell text of more than 256 KB, nested text included, too large to check"; fi
  if [ "$SECONDS" -ge 15 ]; then block "the check ran longer than 15 seconds, too long to check"; fi
  # The records are copied into segs and feds before any nested check runs, since that reuses SC_REC.
  SC_REC=()
  split_commands "$text"
  for seg in "${SC_REC[@]}"; do
    if [ "$seg" = '|' ]; then
      has_pipe=1
      fed=1
    elif [ -n "$seg" ]; then
      segs+=("$seg")
      feds+=("$fed")
      fed=0
    fi
  done
  SC_REC=()
  for ((k = 0; k < ${#segs[@]}; k++)); do
    seg="${segs[$k]}"
    saved_t="$TXT_PIPE"
    saved_f="$FED_PIPE"
    saved_s="$SEG_IN"
    TXT_PIPE="$has_pipe"
    FED_PIPE="${feds[$k]}"
    check_segment "$mode" "$seg"
    TXT_PIPE="$saved_t"
    FED_PIPE="$saved_f"
    SEG_IN="$saved_s"
  done
  return 0
}

# is_seq <text>: returns 0 when the text is a brace sequence without the braces: numbers, such
# as 1..9 or -3..3..2, or single letters, such as a..e. Sets SQ_KIND to n or a, SQ_A and SQ_B to
# the ends, and SQ_S to the step, which is 1 when absent.
is_seq() {
  if [[ $1 =~ ^(-?[0-9]+)\.\.(-?[0-9]+)(\.\.(-?[0-9]+))?$ ]]; then
    SQ_KIND=n
  elif [[ $1 =~ ^([A-Za-z])\.\.([A-Za-z])(\.\.(-?[0-9]+))?$ ]]; then
    SQ_KIND=a
  else
    return 1
  fi
  SQ_A="${BASH_REMATCH[1]}"
  SQ_B="${BASH_REMATCH[2]}"
  SQ_S="${BASH_REMATCH[4]:-1}"
  return 0
}

# seq_values: sets SQ_OUT to the words of the sequence in SQ_A, SQ_B and SQ_S, as bash makes
# them. A step of 0 counts as 1, and a negative step counts in its absolute value. Numbers keep
# the width of the wider end when one of them has a leading zero. A sequence of more than 4096
# words, or with an end or step longer than 9 digits, is blocked as too complex.
seq_values() {
  local a b s d cnt i v w hx dir width sign x
  SQ_OUT=()
  s="${SQ_S#-}"
  if [ "${#s}" -gt 9 ]; then block "a brace pattern that expands to too many words"; fi
  s=$((10#$s))
  if [ "$s" -eq 0 ]; then s=1; fi
  width=0
  if [ "$SQ_KIND" = a ]; then
    printf -v a '%d' "'$SQ_A"
    printf -v b '%d' "'$SQ_B"
  else
    if [ "${#SQ_A}" -gt 10 ] || [ "${#SQ_B}" -gt 10 ]; then
      block "a brace pattern that expands to too many words"
    fi
    x="$SQ_A"; sign=1
    case "$x" in -*) sign=-1; x="${x#-}" ;; esac
    a=$((sign * 10#$x))
    x="$SQ_B"; sign=1
    case "$x" in -*) sign=-1; x="${x#-}" ;; esac
    b=$((sign * 10#$x))
    if [[ $SQ_A =~ ^-?0[0-9] ]] || [[ $SQ_B =~ ^-?0[0-9] ]]; then
      width=${#SQ_A}
      if [ "${#SQ_B}" -gt "$width" ]; then width=${#SQ_B}; fi
    fi
  fi
  dir=1
  d=$((b - a))
  if [ "$d" -lt 0 ]; then dir=-1; d=$((-d)); fi
  cnt=$((d / s + 1))
  if [ "$cnt" -gt 4096 ]; then block "a brace pattern that expands to too many words"; fi
  for ((i = 0; i < cnt; i++)); do
    v=$((a + dir * s * i))
    if [ "$SQ_KIND" = a ]; then
      printf -v hx '%x' "$v"
      printf -v w "\\x$hx"
    else
      printf -v w '%0*d' "$width" "$v"
    fi
    SQ_OUT+=("$w")
  done
}

# brace_span <word>: finds the first {a,b} group or {a..b} sequence, as the shell does. A nested
# { raises a level and its } lowers it, so nested groups stay inside the group. The group ends
# at the } that is at level 0 after a comma at level 0, or at the first } at level 0 that closes
# a sequence. A } at level 0 before either is a literal character. Sets BS_OPEN and BS_CLOSE to
# the positions of the { and the }, and returns 0. A { with no closing } is literal, and the scan
# goes on after it. Returns 1 when there is no group.
brace_span() {
  local s="$1" n i k c d sawc seq
  n="${#s}"
  for ((i = 0; i < n; i++)); do
    BRACE_STEPS=$((BRACE_STEPS + 1))
    [ "${s:i:1}" = '{' ] || continue
    d=0
    sawc=0
    seq=0
    for ((k = i + 1; k < n; k++)); do
      BRACE_STEPS=$((BRACE_STEPS + 1))
      c="${s:k:1}"
      if [ "$c" = '{' ]; then
        d=$((d + 1))
      elif [ "$c" = '}' ]; then
        if [ "$d" -gt 0 ]; then d=$((d - 1))
        elif [ "$sawc" = 1 ]; then break
        elif is_seq "${s:i+1:k-i-1}"; then seq=1; break
        fi
      elif [ "$c" = ',' ] && [ "$d" -eq 0 ]; then
        sawc=1
      fi
    done
    # The steps are counted for the whole word, since a word with many unclosed { would take a
    # quadratic scan, so such a word is blocked instead.
    if [ "$BRACE_STEPS" -gt 10000 ]; then block "a brace pattern too long to check"; fi
    if [ "$k" -lt "$n" ] && { [ "$sawc" = 1 ] || [ "$seq" = 1 ]; }; then
      BS_OPEN=$i
      BS_CLOSE=$k
      return 0
    fi
  done
  return 1
}

# brace_words <word>: returns 0 when the word has a {a,b} group, and sets BW to the words the
# shell makes from it, with nested groups expanded too. Only the commas at the top level of
# a group split its alternatives, so r{m,{x,y}} gives rm, rx and ry. Returns 1 when there is
# no group.
brace_words() {
  BRACE_STEPS=0
  brace_expand "$1"
}

# brace_expand <word>: the recursive part of brace_words. The step count is kept across the
# recursion, so it covers the whole word.
brace_expand() {
  local bword="$1" pre inner post alt c d j
  local -a out=() alts=()
  case "$bword" in
    *'{'*'}'*) ;;
    *) return 1 ;;
  esac
  brace_span "$bword" || return 1
  pre="${bword:0:BS_OPEN}"
  inner="${bword:BS_OPEN+1:BS_CLOSE-BS_OPEN-1}"
  post="${bword:BS_CLOSE+1}"
  if is_seq "$inner"; then
    seq_values
    alts=("${SQ_OUT[@]}")
  else
    alt=""
    d=0
    for ((j = 0; j < ${#inner}; j++)); do
      c="${inner:j:1}"
      if [ "$c" = '{' ]; then
        d=$((d + 1))
      elif [ "$c" = '}' ] && [ "$d" -gt 0 ]; then
        d=$((d - 1))
      elif [ "$c" = ',' ] && [ "$d" -eq 0 ]; then
        alts+=("$alt")
        alt=""
        continue
      fi
      alt+="$c"
    done
    alts+=("$alt")
  fi
  for alt in "${alts[@]}"; do
    if brace_expand "$pre$alt$post"; then
      out+=("${BW[@]}")
    else
      out+=("$pre$alt$post")
    fi
    # Nested groups multiply, so a word that expands to too many words is blocked.
    if [ "${#out[@]}" -gt 4096 ]; then block "a brace pattern that expands to too many words"; fi
  done
  BW=("${out[@]}")
  return 0
}

# check_words <resolved|literal> <word>...: checks one simple command after its wrappers
# are skipped. Shell text that the command runs is checked in the same mode.
check_words() {
  local mode="$1" cmd sub script t i j wrap=0 wname="" ops=0 attached shin sflag pat seen
  local pe fx st file rec frc c scanned=0 dd=0 nskip
  shift
  WORK_CMDS=$((WORK_CMDS + 1))
  if [ "$WORK_CMDS" -gt 5000 ]; then block "more than 5000 simple commands, too many to check"; fi
  if [ "$SECONDS" -ge 15 ]; then block "the check ran longer than 15 seconds, too long to check"; fi
  local -a tok=("$@") rest args ex=()
  # Brace groups are expanded in every word, as the shell expands them, before the words are
  # read as options, file names or wrappers. A quoted word has no group, since its braces are
  # markers. The words of one command are limited to 4096 in all.
  for t in "${tok[@]}"; do
    if brace_words "$t"; then ex+=("${BW[@]}"); else ex+=("$t"); fi
    if [ "${#ex[@]}" -gt 4096 ]; then block "a brace pattern that expands to too many words"; fi
  done
  tok=("${ex[@]}")
  while [ "${#tok[@]}" -gt 0 ]; do
    cmd_name "${tok[0]}"
    cmd="$CMD"
    # GNU getopt permutes arguments, so su, runuser, script and flock still read a command option
    # after their first operand. The words after it are scanned once per wrapper, up to a --.
    if [ "$wrap" = 1 ] && [ "${tok[0]}" = -- ]; then dd=1; fi
    if [ "$wrap" = 1 ] && [ "$scanned" = 0 ] && [[ "${tok[0]}" != -* ]]; then
      case "$wname" in
        su | runuser | script | flock)
          scanned=1
          for ((j = 1; j < ${#tok[@]}; j++)); do
            if [ "${tok[j]}" = -- ]; then break; fi
            if wrap_text_opt "$wname" "${tok[j]}"; then
              if [ "$WT_NEXT" = 1 ]; then script="${tok[j+1]:-}"; else script="$WT_VAL"; fi
              check_text "$mode" "$script"
            fi
          done
          ;;
      esac
    fi
    if [[ "${tok[0]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      tok=("${tok[@]:1}")
    elif [ "$wrap" = 1 ] && [[ "${tok[0]}" == -* ]]; then
      # An option after a wrapper belongs to it, and its value options are per wrapper.
      if [ "$wname" = env ] && { [[ "${tok[0]}" == --split-string* ]] || env_split "${tok[0]}"; }; then
        # env -S, env -SVALUE, env -iS, env --split-string and env --split-string=VALUE: the
        # rest of the text is a command string, checked in the same mode.
        case "${tok[0]}" in
          --split-string=*) attached="${tok[0]#--split-string=}" ;;
          --split-string*) attached="" ;;
          *) attached="$SPLIT_REST" ;;
        esac
        script="$attached"
        for ((j = 1; j < ${#tok[@]}; j++)); do script+=" ${tok[$j]}"; done
        check_text "$mode" "$script"
        return 0
      elif wrap_text_opt "$wname" "${tok[0]}"; then
        # su -c, runuser --command, flock -c and script -qc: the value is shell text. Every value is
        # checked, since util-linux uses the last one, so the option and its value are consumed here.
        if [ "$WT_NEXT" = 1 ]; then
          script="${tok[1]:-}"
          nskip=2
        else
          script="$WT_VAL"
          nskip=1
        fi
        # The scan has checked this value already, unless a -- has come since, which ends its reach.
        if [ "$scanned" = 0 ] || [ "$dd" = 1 ]; then check_text "$mode" "$script"; fi
        tok=("${tok[@]:$nskip}")
      elif wrapper_value "$wname" "${tok[0]}"; then
        tok=("${tok[@]:2}")
      else
        tok=("${tok[@]:1}")
      fi
    elif [ "$wrap" = 1 ] && { [ "$wname" = watch ] || [ "$wname" = parallel ]; }; then
      # watch and parallel run their operands as shell text, from the first operand on.
      script=""
      for ((j = 0; j < ${#tok[@]}; j++)); do script+="${tok[$j]} "; done
      check_text "$mode" "$script"
      return 0
    elif [ "$wrap" = 1 ] && [ "$ops" -gt 0 ]; then
      # A positional operand of the wrapper, such as the CPU mask of taskset.
      tok=("${tok[@]:1}")
      ops=$((ops - 1))
    elif [ "$wrap" = 1 ] && [[ "${tok[0]}" =~ ^[0-9]+[smhd]?$ ]]; then
      tok=("${tok[@]:1}")
    else
      case "$cmd" in
        if | then | else | elif | do | while | until | '!' | '{' | '}' | time | env | command | exec | nohup | nice | timeout | builtin | xargs | stdbuf | setsid | ionice | busybox | wsl | unbuffer | chrt | taskset | su | doas | pkexec | runuser | watch | flock | script | strace | chroot | parallel | setarch | eatmydata | systemd-run | unshare)
          wrap=1
          wname="$cmd"
          scanned=0
          dd=0
          case "$cmd" in taskset | chrt | setarch | chroot | flock | su) ops=1 ;; esac
          tok=("${tok[@]:1}")
          ;;
        coproc)
          # coproc NAME { body }: bash takes NAME only when a compound command follows it.
          # In coproc NAME cmd, bash runs NAME as the command, so NAME is not skipped there.
          wrap=1
          wname="$cmd"
          tok=("${tok[@]:1}")
          if [[ "${tok[0]:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && [ "${tok[1]:-}" = '{' ]; then
            tok=("${tok[@]:1}")
          fi
          ;;
        function)
          # function NAME { body } and function NAME() { body }: skip the keyword and the
          # name, so the body is checked.
          tok=("${tok[@]:2}")
          ;;
        *) break ;;
      esac
    fi
  done
  [ "${#tok[@]}" -gt 0 ] || return 0
  # [, [[, {, } and ! are shell words, not patterns. A command word with an unquoted glob, such
  # as [r]m, is blocked.
  case "${tok[0]}" in
    '[' | '[[' | '{' | '}' | '!') ;;
    *'*'* | *'?'* | *'['*) block "a command name with a glob pattern" ;;
  esac
  cmd_name "${tok[0]}"
  cmd="$CMD"
  rest=("${tok[@]:1}")
  case "$cmd" in
    sudo)
      block "sudo"
      ;;
    rm)
      for t in "${rest[@]}"; do
        # -Re is an unambiguous prefix of -Recurse in Remove-Item, as -rec is.
        case "$t" in -[Rr][Ee]*) block "rm -Recurse" ;; esac
      done
      # rec and frc come from POSIX short clusters (-rf, -Rf), from GNU long prefixes (--r, --f),
      # and from PowerShell -Force (any case, from -fo). A short cluster holds only rm's own
      # letters (d f i I P R r v W x). Any other word after a dash, such as -Force, -LiteralPath
      # or -Filter, is a PowerShell word, not a cluster.
      rec=0
      frc=0
      for t in "${rest[@]}"; do
        case "$t" in
          --*) ;;
          -[Ff][Oo]*) frc=1 ;;
          -*)
            c="${t#-}"
            case "$c" in
              *[!dfiIPRrvWx]*) ;;
              *)
                case "$t" in *[rR]*) rec=1 ;; esac
                case "$t" in *f*) frc=1 ;; esac
                ;;
            esac
            ;;
        esac
      done
      if { [ "$rec" = 1 ] || has_long_prefix r "${rest[@]}"; } \
        && { [ "$frc" = 1 ] || has_long_prefix f "${rest[@]}"; }; then
        block "a recursive forced delete (rm -rf)"
      fi
      ;;
    chmod)
      for t in "${rest[@]}"; do
        case "$t" in
          -*) ;;
          [1-7]777 | 0*[1-7]777) block "chmod 777 with a setuid, setgid or sticky digit" ;;
          777 | 0*777) block "chmod 777" ;;
          *) break ;;
        esac
      done
      ;;
    git)
      i=0
      while [ "$i" -lt "${#rest[@]}" ]; do
        case "${rest[$i]}" in
          -C | -c | --git-dir | --work-tree | --namespace | --super-prefix) i=$((i + 2)) ;;
          -*) i=$((i + 1)) ;;
          *) break ;;
        esac
      done
      sub="${rest[$i]:-}"
      args=("${rest[@]:$((i + 1))}")
      # A .env file named after the subcommand, such as HEAD:.env, is blocked.
      for t in "${args[@]}"; do
        env_block git "${t##*:}"
      done
      case "$sub" in
        push)
          for t in "${args[@]}"; do
            case "$t" in
              --force*) block "a force push" ;;
              --mirror) block "a mirror push, which is a force push" ;;
              --*) ;;
              -*) case "$t" in *f*) block "a force push (-f)" ;; esac ;;
              +*) block "a forced refspec push (+ref)" ;;
            esac
          done
          ;;
        reset)
          for t in "${args[@]}"; do
            case "$t" in --ha*) block "git reset --hard" ;; esac
          done
          ;;
        clean)
          if has_flag 'f' "${args[@]}" || has_long_prefix f "${args[@]}"; then
            block "git clean with force"
          fi
          ;;
      esac
      ;;
    del | erase | rd | ri | remove-item | rmdir)
      # -R is an unambiguous prefix of the Remove-Item parameter -Recurse.
      for t in "${rest[@]}"; do
        case "$t" in -[Rr]*) block "$cmd -Recurse" ;; esac
      done
      ;;
    trap)
      # The first operand is the action, unless it is an option. A -- before it ends the
      # options, so the action follows it.
      t="${rest[0]:-}"
      if [ "$t" = -- ]; then t="${rest[1]:-}"; fi
      if [ -n "$t" ] && [[ "$t" != -* ]]; then check_text "$mode" "$t"; fi
      ;;
    grep | egrep | fgrep | rg | sed | awk)
      # The first operand is the pattern or program, unless a pattern option names it. The
      # other operands are files. For awk the pattern option is -f only. The long forms of
      # --regexp and --file in grep, and of --expression and --file in sed, count with the
      # prefixes that getopt_long accepts. A prefix is too short when another option has it too.
      pat=0
      if [ "$cmd" = awk ]; then
        if has_flag 'f' "${rest[@]}"; then pat=1; fi
      else
        if has_flag '[ef]' "${rest[@]}"; then pat=1; fi
        for t in "${rest[@]}"; do
          if [ "$cmd" = sed ]; then
            if long_is "$t" expression 1 || long_is "$t" file 2; then pat=1; fi
          elif long_is "$t" regexp 3 || long_is "$t" file 4; then
            pat=1
          fi
        done
      fi
      seen=0
      for t in "${rest[@]}"; do
        case "$t" in
          --*=*) env_block "$cmd" "${t#*=}" ;;
          --*) ;;
          -?*)
            # A value attached to an option, such as -f.env, is checked as a file.
            case "$t" in *[ef]*) env_block "$cmd" "${t#*[ef]}" ;; esac
            ;;
          *)
            if [ "$pat" = 0 ] && [ "$seen" = 0 ]; then
              seen=1
            else
              env_block "$cmd" "$t"
            fi
            ;;
        esac
      done
      ;;
    find)
      # A -name, -iname, -path or -ipath that names .env is blocked when the command also has an
      # exec option, or when the text has a pipe (TXT_PIPE, set by check_text).
      pe=0
      fx=0
      for ((i = 0; i < ${#tok[@]}; i++)); do
        case "${tok[$i]}" in
          -name | -iname | -path | -ipath)
            if [ "$((i + 1))" -lt "${#tok[@]}" ]; then
              base_name "${tok[$((i + 1))]}"
              if env_name 1; then pe=1; fi
            fi
            ;;
          -exec | -execdir | -ok | -okdir) fx=1 ;;
        esac
      done
      if [ "$pe" = 1 ] && { [ "$fx" = 1 ] || [ "$TXT_PIPE" = 1 ]; }; then
        block "find with a .env name and an exec or a pipe"
      fi
      for ((i = 0; i < ${#tok[@]}; i++)); do
        case "${tok[$i]}" in
          -exec | -execdir | -ok | -okdir)
            args=()
            for ((j = i + 1; j < ${#tok[@]}; j++)); do
              case "${tok[$j]}" in ';' | '+') break ;; esac
              args+=("${tok[$j]}")
            done
            check_words "$mode" "${args[@]}"
            ;;
        esac
      done
      ;;
    bash | sh | zsh | dash | ksh | ash)
      # With no -c and no script operand, the shell reads its commands from stdin.
      # -s also means stdin, and any operand after it is an argument.
      shin=1
      sflag=0
      for ((i = 0; i < ${#rest[@]}; i++)); do
        t="${rest[$i]}"
        case "$t" in
          -o | +o | -O | +O) i=$((i + 1)) ;;
          # --rcfile and --init-file take a file as the next word, which is not a script.
          --rcfile | --init-file) i=$((i + 1)) ;;
          # --help and --version print and exit, so they read no commands.
          --help | --version) shin=0; break ;;
          --*) ;;
          -*c*) check_text "$mode" "${rest[$((i + 1))]:-}"; shin=0; break ;;
          -*s*) sflag=1 ;;
          -*) ;;
          *) if [ "$sflag" = 0 ]; then shin=0; fi; break ;;
        esac
      done
      if [ "$shin" = 1 ]; then block "a shell that reads commands from stdin"; fi
      ;;
    fish | rbash | mksh | csh | tcsh | ksh93)
      # These shells have no stdin rule here, but the text of their -c option is checked.
      for ((i = 0; i < ${#rest[@]}; i++)); do
        case "${rest[$i]}" in
          --*) ;;
          -*c*) check_text "$mode" "${rest[$((i + 1))]:-}"; break ;;
        esac
      done
      ;;
    cmd)
      # cmd /c, /k and /r take the text after them, and the switch can be attached, as in
      # /c"text". With none of them, cmd reads its commands from stdin, so it is blocked.
      st=-1
      script=""
      for ((i = 0; i < ${#rest[@]}; i++)); do
        case "${rest[$i]}" in
          /[CcKkRr]*)
            st=1
            script="${rest[$i]:2} "
            for ((j = i + 1; j < ${#rest[@]}; j++)); do script+="${rest[$j]} "; done
            break
            ;;
        esac
      done
      if [ "$st" = -1 ]; then block "a cmd that reads commands from stdin"; fi
      check_text "$mode" "$script"
      ;;
    powershell | pwsh)
      # -Command takes the text after it. -File and -EncodedCommand do not take text here.
      # With no command switch, the operands are command text, after the switches and their
      # values. With none of these, PowerShell reads its commands from stdin, so it is blocked.
      st=-1
      file=0
      for ((i = 0; i < ${#rest[@]}; i++)); do
        t="${rest[$i]}"
        case "$t" in
          -[Cc]*) st=$((i + 1)); break ;;
          -[Ff]*) file=1; break ;;
          -[Ee][Xx]* | -[Ee][Pp]* | -[Ww][Ii]* | -[Ii][Nn]* | -[Ii][Ff] | -[Oo][Uu]* | -[Oo][Ff])
            i=$((i + 1))
            ;;
          -[Ee]*) file=1; break ;;
          -*) ;;
          *) st=$i; break ;;
        esac
      done
      if [ "$file" = 0 ] && { [ "$st" -lt 0 ] || [ "$st" -ge "${#rest[@]}" ]; }; then
        block "a PowerShell that reads commands from stdin"
      fi
      if [ "$st" -ge 0 ] && [ "$st" -lt "${#rest[@]}" ]; then
        script=""
        for ((j = st; j < ${#rest[@]}; j++)); do script+="${rest[$j]} "; done
        check_text "$mode" "$script"
      fi
      ;;
    iex | invoke-expression)
      # A string operand is PowerShell text, so each operand is checked as a command.
      for t in "${rest[@]}"; do check_text "$mode" "$t"; done
      ;;
    at | batch)
      # at and batch read their commands from stdin, so a pipe or a here-string feeds them.
      if [ "$SEG_IN" = 1 ] && ! has_flag f "${rest[@]}"; then
        block "at or batch fed by a pipe or a here-string"
      fi
      ;;
    eval)
      script=""
      for t in "${rest[@]}"; do script+="$t "; done
      check_text "$mode" "$script"
      ;;
    *)
      case "$cmd" in
        get-content | set-content | add-content | out-file)
          for t in "${rest[@]}"; do
            case "$t" in *.[Ee][Nn][Vv]*) block "a .env file given to $cmd" ;; esac
            # -Path:NAME names a file after the colon. Other words are operands, which may be
            # globs such as .e* or *, so they are matched as PowerShell matches names (env_name 1).
            case "$t" in
              -*:*) env_block "$cmd" "${t#*:}" 1 ;;
              -*) ;;
              *) env_block "$cmd" "$t" 1 ;;
            esac
          done
          ;;
        cat | head | tail | less | more | tee | cp | mv | source | . | xxd | od | hexdump | strings | bat | type | nl | tac | base64 | sort | diff | cmp | vi | vim | nano | code | dd | install | rsync | scp | wc | cut | paste | file | stat | md5sum | sha1sum | sha256sum | shasum | zcat | gzip | jq | gc | sc | ac | sls | select-string | copy | move | tar | zip | unzip | 7z | openssl | gpg | nvim | emacs | ex | comm | split | fold | xz | bzip2 | zstd | gunzip | base32 | column | uniq | rev | iconv | truncate | findstr | xcopy | certutil | ln)
          for t in "${rest[@]}"; do
            # name=value arguments, such as dd if=.env, are checked by their value.
            env_block "$cmd" "${t##*=}"
            # tar -f.env and tar -cf.env: f takes the rest of its option cluster as the name.
            if [ "$cmd" = tar ]; then
              case "$t" in
                --*) ;;
                -*f*) env_block "$cmd" "${t#*f}" ;;
              esac
            fi
          done
          ;;
      esac
      ;;
  esac
}

# run-hook.sh renames Execute and Create, and the guard accepts both names too, so a call that
# reaches the guard unrenamed is checked the same way.
case "$tool" in
  Bash | Execute)
    command_text="$(set -o pipefail; printf '%s' "$input" | jq -r 'if (.tool_input.command | type) == "string" or .tool_input.command == null then (.tool_input.command // empty) else error("the command is not a string") end' 2>/dev/null | tr -d '\r\000')" || block "the command could not be read from the hook payload"
    # The text is checked with backslashes resolved, then, when it has a backslash, with them kept.
    check_text resolved "$command_text"
    # The two modes differ only at a backslash, and every nested text comes from this text, so
    # the literal pass is skipped when there is no backslash.
    case "$command_text" in
      *\\*) check_text literal "$command_text" ;;
    esac
    ;;
  Read | Write | Create | Edit | Grep)
    # Grep names its file in path. A folder path is not checked.
    pk=file_path
    if [ "$tool" = Grep ]; then pk=path; fi
    path="$(set -o pipefail; printf '%s' "$input" | jq -r --arg k "$pk" 'if (.tool_input[$k] | type) == "string" or .tool_input[$k] == null then (.tool_input[$k] // empty) else error("the path is not a string") end' 2>/dev/null | tr -d '\r\000')" || block "the file path could not be read from the hook payload"
    base_name "$path"
    # On Windows, Foo.uasset::$DATA is Foo.uasset, and .env. or Foo.uasset is the same file
    # as .env or Foo.uasset, so the colon part and trailing dots and spaces are removed.
    NAME="${NAME%%:*}"
    while [ -n "$NAME" ]; do
      case "$NAME" in
        *. | *' ') NAME="${NAME%?}" ;;
        *) break ;;
      esac
    done
    case "$NAME" in
      .env*) block "a read, write or search of a .env file" ;;
    esac
    if [ "$tool" = Write ] || [ "$tool" = Create ] || [ "$tool" = Edit ]; then
      case "$NAME" in
        *.uasset | *.umap) block "an edit of a binary Unreal asset" ;;
      esac
    fi
    ;;
esac
# A check that finished after the time limit is blocked too, in case the watchdog did not run.
if [ "$SECONDS" -ge 15 ]; then block "the check ran longer than 15 seconds, too long to check"; fi
exit 0
