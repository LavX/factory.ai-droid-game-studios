#!/usr/bin/env bash
# test-guard.sh: regression cases for guard-destructive.sh. Each case goes through
# run-hook.sh the way hooks.json runs it, so the Factory payload rewrite is tested
# too. From the project root:
#   bash .factory/hooks/test-guard.sh
# Exit 2 from the guard means blocked, exit 0 means allowed. The CRLF cases put a
# stand-in for a native Windows jq.exe first on PATH; it ends each output line with
# CR. The rewrite-failure case puts a jq that fails the adapter's rewrite first on PATH.
# The read-failure cases put a cat first on PATH that prints one complete harmless call and then
# fails, and the tr cases put a tr first on PATH that fails on the payload read or on the
# lowercase step. The field-read cases put a jq first on PATH that fails one of the adapter's
# field reads. The session-id case puts a tr first on PATH that fails the session filter. The
# no-jq case puts a PATH without jq first, with a sed that fails. The directory case puts a
# dirname that fails first. The bash 3.2 cases run a copy
# of the guard without its bash 4 branch. The
# direct cases run the guard without run-hook.sh, so Factory's tool names reach it unrenamed.
# Needs jq. Exits 1 when a case fails.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_JQ="$(command -v jq 2>/dev/null)"
if [ -z "$REAL_JQ" ]; then
  echo "test-guard: jq is not installed, so the guard cannot run." >&2
  exit 1
fi
export REAL_JQ

crlf_dir="$(mktemp -d)"
fail_dir="$(mktemp -d)"
extra_dir="$(mktemp -d)"
trap 'rm -r "$crlf_dir" "$fail_dir" "$extra_dir"' EXIT
cat > "$crlf_dir/jq" <<'WRAP'
#!/usr/bin/env bash
# Stand-in for a native Windows jq.exe: the real jq, with CRLF line ends.
"$REAL_JQ" "$@" | awk '{ printf "%s\r\n", $0 }'
WRAP
chmod +x "$crlf_dir/jq"
CRLF_PATH="$crlf_dir:$PATH"
# Stand-in that fails only the adapter's rewrite, the one filter that names upstream_tool.
cat > "$fail_dir/jq" <<'WRAP'
#!/usr/bin/env bash
case "$*" in
  *upstream_tool*) exit 5 ;;
esac
exec "$REAL_JQ" "$@"
WRAP
chmod +x "$fail_dir/jq"
FAIL_PATH="$fail_dir:$PATH"
# Stand-in for a cat that prints one complete harmless call, then fails, as a read that breaks part
# way would. Each hook reads its payload through cat, so this stand-in is first on PATH for it.
mkdir -p "$extra_dir/read_fail" "$extra_dir/tr_read_fail" "$extra_dir/tr_case_fail" "$extra_dir/fallback"
cat > "$extra_dir/read_fail/cat" <<'WRAP'
#!/usr/bin/env bash
printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Execute","tool_input":{"command":"echo hi"}}'
exit 1
WRAP
chmod +x "$extra_dir/read_fail/cat"
READ_FAIL_PATH="$extra_dir/read_fail:$PATH"
# Stand-ins for tr that fail on the guard's payload read, and on its lowercase step.
REAL_TR="$(command -v tr)"
export REAL_TR
cat > "$extra_dir/tr_read_fail/tr" <<'WRAP'
#!/usr/bin/env bash
case "$*" in *'\000-\003'*) exit 1 ;; esac
exec "$REAL_TR" "$@"
WRAP
cat > "$extra_dir/tr_case_fail/tr" <<'WRAP'
#!/usr/bin/env bash
case "$*" in *'[:upper:]'*) exit 1 ;; esac
exec "$REAL_TR" "$@"
WRAP
chmod +x "$extra_dir/tr_read_fail/tr" "$extra_dir/tr_case_fail/tr"
TR_READ_FAIL_PATH="$extra_dir/tr_read_fail:$PATH"
TR_CASE_FAIL_PATH="$extra_dir/tr_case_fail:$PATH"
# field_fail <name> <jq filter>: prints a PATH with a jq first that fails when its arguments contain
# the filter. Each filter is one adapter read, so that read is what fails, not a later rewrite.
field_fail() {
  local dir="$extra_dir/field_$1"
  mkdir -p "$dir"
  cat > "$dir/jq" <<WRAP
#!/usr/bin/env bash
case "\$*" in *'$2'*) exit 5 ;; esac
exec "\$REAL_JQ" "\$@"
WRAP
  chmod +x "$dir/jq"
  printf '%s' "$dir:$PATH"
}
EVENT_FAIL_PATH="$(field_fail event '.hook_event_name // empty')"
SESSION_FAIL_PATH="$(field_fail session '.session_id // empty')"
TOOL_FAIL_PATH="$(field_fail tool '.tool_name // empty')"
CALLER_FAIL_PATH="$(field_fail caller '.calling_session_id // empty')"
SUBTYPE_FAIL_PATH="$(field_fail subtype '.tool_input.subagent_type? // empty')"
DESC_FAIL_PATH="$(field_fail desc '.tool_input.description? // empty')"
TASK_FAIL_PATH="$(field_fail task '.task_name // empty')"
# A tr that fails on the session id filter, so the adapter must stop instead of using an empty id.
mkdir -p "$extra_dir/session_tr_fail"
cat > "$extra_dir/session_tr_fail/tr" <<'WRAP'
#!/usr/bin/env bash
case "$*" in *'A-Za-z0-9_-'*) exit 1 ;; esac
exec "$REAL_TR" "$@"
WRAP
chmod +x "$extra_dir/session_tr_fail/tr"
SESSION_TR_FAIL_PATH="$extra_dir/session_tr_fail:$PATH"
# A PATH with no jq, so the adapter takes its sed rewrite, and a sed that fails. The directory links
# only the commands the adapter runs before that rewrite.
mkdir -p "$extra_dir/nojq"
for cmd in bash cat dirname; do ln -s "$(command -v "$cmd")" "$extra_dir/nojq/$cmd"; done
printf '#!%s\nexit 1\n' "$(command -v bash)" > "$extra_dir/nojq/sed"
chmod +x "$extra_dir/nojq/sed"
NOJQ_SED_FAIL_PATH="$extra_dir/nojq"
# A dirname that fails, so the adapter cannot find its own directory and must stop.
mkdir -p "$extra_dir/dirname_fail"
printf '#!/usr/bin/env bash\nexit 1\n' > "$extra_dir/dirname_fail/dirname"
chmod +x "$extra_dir/dirname_fail/dirname"
DIRNAME_FAIL_PATH="$extra_dir/dirname_fail:$PATH"
# A copy of the guard without its bash 4 branch, so base_name takes the bash 3.2 branch.
sed 's/if \[ "\${BASH_VERSINFO\[0\]:-3}" -ge 4 \]; then/if false; then/' "$HERE/guard-destructive.sh" > "$extra_dir/fallback/guard-destructive.sh"
if ! grep -q '^  if false; then$' "$extra_dir/fallback/guard-destructive.sh"; then
  echo "test-guard: the bash 3.2 copy of the guard did not change, so the bash 3.2 cases would prove nothing." >&2
  exit 1
fi

if ! printf '"x"' | PATH="$CRLF_PATH" jq -r . | grep -q "$(printf '\r')"; then
  echo "test-guard: the CRLF stand-in does not emit CR, so the CRLF cases would prove nothing." >&2
  exit 1
fi

pass=0
fail=0

# verdict <block|allow> <label> <exit code>: counts one case.
verdict() {
  if { [ "$1" = block ] && [ "$3" = 2 ]; } || { [ "$1" = allow ] && [ "$3" = 0 ]; }; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected $1, exit was $3: $2"
  fi
}

# expect <block|allow> <label> <payload> [PATH]: runs the payload through run-hook.sh.
expect() {
  local want="$1" label="$2" payload="$3" path="${4:-$PATH}" got
  printf '%s' "$payload" | PATH="$path" bash "$HERE/run-hook.sh" guard-destructive.sh >/dev/null 2>&1
  got=$?
  verdict "$want" "$label" "$got"
}

# direct <block|allow> <label> <payload>: runs the guard without run-hook.sh, so Factory's tool
# names reach it unrenamed.
direct() {
  local got
  printf '%s' "$3" | bash "$HERE/guard-destructive.sh" >/dev/null 2>&1
  got=$?
  verdict "$1" "$2" "$got"
}

# guard_case <block|allow> <label> <script> <payload> [PATH] [text]: runs a guard script directly,
# without run-hook.sh. A block must also name text on stderr, when text is given.
guard_case() {
  local want="$1" label="$2" script="$3" payload="$4" path="${5:-$PATH}" text="${6:-}" got err
  err="$(printf '%s' "$payload" | PATH="$path" bash "$script" 2>&1 >/dev/null)"
  got=$?
  verdict "$want" "$label" "$got"
  if [ -n "$text" ] && [ "$want" = block ]; then
    case "$err" in *"$text"*) ;; *) fail=$((fail + 1)); echo "FAIL: stderr does not name the check ($text): $label" ;; esac
  fi
}

# adapter_block <label> <script> <payload> <text> [PATH]: a block through run-hook.sh that must
# also name text on stderr, so a block from some other check is caught.
adapter_block() {
  local label="$1" script="$2" payload="$3" text="$4" path="${5:-$PATH}" got err
  err="$(printf '%s' "$payload" | PATH="$path" bash "$HERE/run-hook.sh" "$script" 2>&1 >/dev/null)"
  got=$?
  verdict block "$label" "$got"
  case "$err" in *"$text"*) ;; *) fail=$((fail + 1)); echo "FAIL: stderr does not name the check ($text): $label" ;; esac
}

# bash_case <block|allow> <command> [PATH]
bash_case() {
  expect "$1" "$2" "$(jq -cn --arg c "$2" '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: $c}}')" "$3"
}

# path_case <block|allow> <tool> <path> [PATH]
path_case() {
  expect "$1" "$2 $3" "$(jq -cn --arg t "$2" --arg p "$3" '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: {file_path: $p}}')" "$4"
}

# grep_case <block|allow> <path>: a Grep call whose path is the given file or folder.
grep_case() {
  expect "$1" "Grep $2" "$(jq -cn --arg p "$2" '{hook_event_name: "PreToolUse", tool_name: "Grep", tool_input: {pattern: "x", path: $p}}')"
}

# big_case <block|allow> <label> <command>: bash_case for a command over 128 KB, the most one
# argument can hold, so the command goes to jq on stdin.
big_case() {
  expect "$1" "$2" "$(printf '%s' "$3" | jq -Rsc '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: .}}')"
}

echo "Blocked shell commands"
bash_case block 'rm -rf build'
bash_case block 'rm -fr out/'
bash_case block 'rm -r -f build'
bash_case block 'rm --recursive --force build'
bash_case block '"rm" -rf build'
bash_case block '\rm -rf build'
bash_case block '/bin/rm -rf build'
bash_case block 'git reset --hard'
bash_case block 'git reset --hard HEAD~1'
bash_case block 'git -C . reset --hard'
bash_case block 'git -c core.autocrlf=false reset --hard'
bash_case block 'git --no-pager reset --hard'
bash_case block 'git push --force origin main'
bash_case block 'git push origin main --force'
bash_case block 'git -C . push origin main --force'
bash_case block 'git push origin +main'
bash_case block 'git push -uf origin main'
bash_case block 'git push --force-with-lease origin feature'
bash_case block 'git clean -fdx'
bash_case block 'git -C repo clean -fd'
bash_case block 'chmod 777 run.sh'
bash_case block 'chmod -R 777 build'
bash_case block 'chmod 0777 run.sh'
bash_case block 'sudo ls /root'
bash_case block 'env FOO=1 sudo ls'
bash_case block 'echo ok && sudo ls'
bash_case block 'echo ok; rm -rf build'
bash_case block 'cat list.txt | xargs rm -rf'
bash_case block '(rm -rf build)'
bash_case block 'echo $(rm -rf build)'
bash_case block 'echo "$(rm -rf build)"'
bash_case block 'echo "$( (echo ok); sudo id )"'
bash_case block 'echo `rm -rf build`'
bash_case block 'bash -c "rm -rf build"'
bash_case block 'bash -o pipefail -c "rm -rf build"'
bash_case block 'sh -lc "git reset --hard"'
bash_case block 'eval "rm -rf build"'
bash_case block 'find . -name tmp -exec rm -rf {} +'
bash_case block 'find . -exec rm -rf {} \;'
bash_case block 'xargs rm -rf'
bash_case block 'nice -n 5 rm -rf build'
bash_case block 'timeout 10 rm -rf build'
bash_case block 'time rm -rf build'
bash_case block 'if true; then rm -rf build; fi'
bash_case block 'for d in a; do rm -rf "$d"; done'
bash_case block 'cat .env'
bash_case block 'cat ./.env.local'
bash_case block 'cat "$HOME/.env"'
bash_case block 'head -n 3 .env'
bash_case block 'cp .env backup'
bash_case block 'tee .env'
bash_case block 'echo KEY=1 > .env'
bash_case block 'echo KEY=1 >> .env'
bash_case block 'source .env'
bash_case block 'bash -c "cat .env"'
bash_case block 'powershell -Command "Remove-Item -Recurse build"'
bash_case block 'pwsh -c "Get-Content .env"'
bash_case block 'Get-Content .env'
bash_case block 'Remove-Item -Recurse -Force build'

echo "Windows names, redirects, and quoting"
bash_case block 'git.exe reset --hard'
bash_case block 'GIT.EXE reset --hard'
bash_case block 'bash.exe -c "rm -rf build"'
bash_case block '"C:\Program Files\Git\bin\git.exe" reset --hard'
bash_case block 'cmd /c rm -rf build'
bash_case block 'cmd.exe /C "git reset --hard"'
bash_case block 'powershell.exe -Command "Remove-Item -Recurse build"'
bash_case block 'type C:\repo\.env'
bash_case block 'cat C:\repo\.env.local'
bash_case block 'gc C:\repo\.env'
bash_case block 'cat .\env'
bash_case block 'cat "C:\repo\.env"'
bash_case block 'Get-Content C:\repo\.env'
bash_case block '2>/dev/null rm -rf build'
bash_case block 'echo ok 2>/dev/null; rm -rf build'
bash_case block 'echo ok > /dev/null && rm -rf build'
bash_case block 'wc -c < .env'
bash_case block 'wc -c <.env'
bash_case block 'wc .env'
bash_case block 'echo x >| .env'
bash_case block 'echo x >.env'
bash_case block 'echo x 2> .env'
bash_case block 'echo x &> .env'
bash_case block 'echo x >& .env'
bash_case block 'echo x > C:\repo\.env'
bash_case block 'dd if=.env of=out.txt'
bash_case block "\$'rm' -rf build"
bash_case block "\$\"rm\" -rf build"
bash_case block "\$'\\x72m' -rf build"
bash_case block "\$'\\162m' -rf build"
bash_case block "echo \$'it\\'s'; rm -rf build"
bash_case block $'echo ok\nrm -rf build'

echo "Comments and heredocs"
bash_case block $'# don\'t\nrm -rf build'
bash_case block $'# say "hi\nrm -rf build'
bash_case block $'echo ok # it\'s\nrm -rf build'
bash_case block 'echo \ #; sudo id'
bash_case block $'cat <<\'EOF\'\nit\'s\nEOF\nrm -rf build'
bash_case block $'cat <<EOF\nsay "hi\nEOF\nrm -rf build'
bash_case block $'cat <<-\'EOF\'\n\tit\'s\n\tEOF\nrm -rf build'
bash_case block $'bash <<\'EOF\'\nrm -rf build\nEOF'
bash_case block $'cat <<EOF\necho ok; rm -rf build\nEOF'
bash_case block $'cat <<< "it\'s"\nrm -rf build'
# Known false positive: a heredoc body line that starts a blocked command is blocked too.
bash_case block $'cat > notes.txt <<\'EOF\'\nrm -rf is dangerous\nEOF'

echo "Wrappers, PowerShell names, globs and readers"
bash_case block 'env -S "rm -rf build"'
bash_case block 'env -S"rm -rf build"'
bash_case block 'env --split-string="rm -rf build"'
bash_case block 'env -C /tmp rm -rf build'
bash_case block 'setsid -f rm -rf build'
bash_case block 'ionice -c3 rm -rf build'
bash_case block 'busybox rm -rf build'
bash_case block "wsl bash -c 'rm -rf build'"
bash_case block 'trap "rm -rf build" EXIT'
bash_case block '/usr/bin/time -f %e rm -rf build'
bash_case block 'function f { rm -rf build; }; f'
bash_case block 'echo "rm -rf build" | sh'
bash_case block 'echo "rm -rf build" | bash -s'
bash_case block 'bash <<< "rm -rf build"'
bash_case block 'cat .e*'
bash_case block 'cat .?nv'
bash_case block 'cat .*env'
bash_case block 'cat docs/.e*'
# Known false positive: a directory name that starts with .env is blocked too.
bash_case block 'cat docs/.environment.md'
bash_case block 'rm -Recurse -Force build'
bash_case block 'del -Recurse -Force build'
bash_case block 'rd -Recurse build'
bash_case block 'remove-item -r build'
bash_case block 'ri -r build'
bash_case block 'del -r build'
bash_case block 'powershell -Command "rm -Recurse -Force build"'
bash_case block 'rm --recurs --forc build'
bash_case block 'chmod 00777 run.sh'
bash_case block 'tar cf x.tar .env'
bash_case block 'openssl enc -in .env -out x'
bash_case block 'git show HEAD:.env'
bash_case block 'git add .env'
bash_case block 'grep -e x .env'
bash_case block 'sed -n 1p .env'
bash_case block 'tar -cf.env README.md'
bash_case block 'tar -f.env README.md'
bash_case block 'tar --file=.env README.md'
bash_case block 'tar -c -f.env README.md'
bash_case block 'timeout --signal TERM 1 sudo id'
bash_case block 'timeout --kill-after 5 sudo id'
bash_case block 'stdbuf --output L sudo id'
bash_case block 'stdbuf --error L sudo id'
bash_case block 'nice --adjustment 5 rm -rf build'
bash_case block 'env --argv0 x sudo id'
bash_case block 'xargs --max-args 1 rm -rf'
bash_case block 'xargs --max-lines 1 rm -rf build'
bash_case block 'ionice --class 3 rm -rf build'
bash_case block 'time --format %e rm -rf build'
bash_case block 'bash --rcfile /dev/null -s'
bash_case block 'bash --init-file x.sh -s'
bash_case block 'bash -s build.sh'
bash_case block 'powershell -Command "Get-Content .e*"'
bash_case block 'powershell -Command "Set-Content -Path .e* x"'
bash_case block 'Get-Content .e*'

echo "Allowed shell commands"
bash_case allow 'rm build.txt'
bash_case allow 'rm -r build'
bash_case allow 'rm -f file.txt'
bash_case allow 'git status'
bash_case allow 'git reset --soft HEAD~1'
bash_case allow 'git push origin main'
bash_case allow 'git push -u origin feature'
bash_case allow 'git clean -n'
bash_case allow 'git -C . status'
bash_case allow 'git -c user.name=test log --oneline'
bash_case allow "git log --format='%h (%an)'"
bash_case allow 'git commit -m "fix: handle (x) and more"'
bash_case allow 'git commit -m "Remove .env; add gitignore"'
bash_case allow 'echo "rm -rf is blocked"'
bash_case allow "echo 'a; rm -rf x'"
bash_case allow 'echo "a $(date)" > out.txt'
bash_case allow 'chmod 755 run.sh'
bash_case allow 'chmod -R 755 build'
bash_case allow 'ls -la .env'
bash_case allow 'cat README.md'
bash_case allow 'cat .github/workflows/ci.yml'
bash_case allow 'grep -r "sudo" docs'
bash_case allow 'grep "a|b" file.txt'
bash_case allow 'sed -n 1,5p README.md'
bash_case allow 'bash scripts/build.sh'
bash_case allow 'bash -c "echo hi"'
bash_case allow 'bash -o pipefail -c "echo ok"'
bash_case allow 'npm test && echo done'
bash_case allow "find . -name '*.md' -exec cat {} +"
bash_case allow 'find . -name "*.sh" -exec bash -n {} \;'
bash_case allow 'echo $HOME'
bash_case allow 'nice -n 5 make build'
bash_case allow 'command -v git'

echo "Allowed Windows names, redirects, and quoting"
bash_case allow 'echo "redirect > .env is forbidden"'
bash_case allow "echo 'redirect > .env'"
bash_case allow 'echo a >out.txt'
bash_case allow 'echo x 2>/dev/null'
bash_case allow 'ls 2>&1'
bash_case allow 'git log --oneline 2>&1 | head -5'
bash_case allow 'wc -l README.md'
bash_case allow 'wc -c < README.md'
bash_case allow 'dd if=README.md of=out.txt'
bash_case allow "echo \$'a\\tb'"
bash_case allow "echo \$'it\\'s fine'"
bash_case allow "echo \$'rm -rf build'"
bash_case allow 'printf "%s\n" ok'
bash_case allow 'cmd /c echo hi'
bash_case allow 'cat C:\Users\me\notes.txt'
bash_case allow 'git status 2>&1 && git log -1'
bash_case allow $'echo "example:\nrm -rf build"'
bash_case allow $'echo "one\ntwo"'

echo "Allowed comments, heredocs, wrappers and search"
bash_case allow 'echo hi # rm -rf build'
bash_case allow $'echo ok\n# it\'s a comment\necho done'
bash_case allow $'cat <<\'EOF\' > notes.txt\nhello\nEOF\necho done'
bash_case allow $'cat <<\'EOF\'\nprint it\'s fine\nEOF'
bash_case allow $'git commit -m "$(cat <<\'EOF\'\nFix the thing\n\nDetails here.\nEOF\n)"'
bash_case allow 'echo $((1 << 2))'
bash_case allow 'grep -rn "\.env" docs'
bash_case allow 'grep .env docs/readme.md'
bash_case allow 'sed -n 1p README.md'
bash_case allow 'cat .gitignore'
bash_case allow 'ls -la .env'
bash_case allow 'chmod 0755 run.sh'
bash_case allow 'time make test'
bash_case allow 'env FOO=1 go test ./...'
bash_case allow 'ionice -c3 make'
bash_case allow 'git show HEAD:README.md'
bash_case allow 'rm --recursive build'
bash_case allow 'echo \\ # rm -rf build'
bash_case allow 'echo "$( (echo ok); echo done )"'
bash_case allow 'echo $(( (1 + 2) * 3 ))'
bash_case allow 'timeout --signal=TERM 10 make test'
bash_case allow 'stdbuf --output=L make'
bash_case allow 'nice --adjustment 5 make build'
bash_case allow 'bash --rcfile /dev/null scripts/build.sh'
bash_case allow 'bash --init-file x.sh -c "echo hi"'
bash_case allow 'powershell -Command "Get-Content -Path README.md"'
bash_case allow 'Get-Content README.md'
bash_case allow 'tar -czf release.tgz docs'

echo "Read, write, and edit paths"
path_case block Read .env
path_case block Read config/.env.local
path_case block Create .env
path_case block Edit .env.local
path_case block Edit Assets/Foo.uasset
path_case block Create Maps/Level.umap
path_case allow Read README.md
path_case allow Read Assets/Foo.uasset
path_case allow Create src/main.gd
path_case allow Edit docs/x.md
path_case block Read 'C:\repo\.env.local'
path_case block Create 'C:\repo\.env'
path_case block Read .ENV
path_case block Edit 'Assets\Foo.UASSET'
path_case block Create 'Maps\Level.UMAP'
path_case allow Read 'C:\repo\README.md'
path_case allow Read 'docs\environment.md'

echo "Wrappers, shell options and shells"
bash_case block 'env -iS "rm -rf x"'
bash_case block 'env -vS"rm -rf x"'
bash_case block 'trap -- "rm -rf x" EXIT'
bash_case block 'coproc rm -rf x'
bash_case block "su -c 'rm -rf x'"
bash_case block "su root -c 'rm -rf x'"
bash_case block 'runuser -u root -- rm -rf x'
bash_case block 'doas rm -rf x'
bash_case block 'pkexec rm -rf x'
bash_case block "watch -n1 'rm -rf x'"
bash_case block "flock /tmp/l -c 'rm -rf x'"
bash_case block 'flock /tmp/l rm -rf x'
bash_case block "script -qc 'rm -rf x' /dev/null"
bash_case block 'strace -o /dev/null rm -rf x'
bash_case block 'chroot . rm -rf x'
bash_case block "parallel 'rm -rf {}' ::: x"
bash_case block 'setarch x86_64 rm -rf x'
bash_case block 'eatmydata rm -rf x'
bash_case block 'systemd-run rm -rf x'
bash_case block 'unshare -r rm -rf x'
bash_case block 'fish -c "rm -rf x"'
bash_case block 'rbash -c "rm -rf x"'
bash_case block 'mksh -c "rm -rf x"'
bash_case block 'csh -c "rm -rf x"'
bash_case block 'tcsh -c "rm -rf x"'
bash_case block 'ksh93 -c "rm -rf x"'
bash_case block 'echo $(( $(rm -rf x) + 1 ))'
bash_case allow 'bash --version'
bash_case allow 'sh --help'
bash_case allow 'bash --help'
bash_case allow 'env -i make test'
bash_case allow 'trap -- "echo hi" EXIT'
bash_case allow 'flock /tmp/l make test'
bash_case allow 'watch -n 2 make'
bash_case allow 'parallel echo ::: a'
bash_case allow 'strace -o trace.txt ls'
bash_case allow 'systemd-run --user make'
bash_case allow 'fish -c "echo hi"'
bash_case allow 'csh -c "echo hi"'

echo "PowerShell, cmd and at"
bash_case block 'powershell -c "rm -r -Force x"'
bash_case block 'pwsh -c "rm -RECURSE -force x"'
bash_case block 'pwsh -c "rmdir -Recurse x"'
bash_case block 'powershell rm -Recurse -Force x'
bash_case block 'powershell.exe -NoProfile Remove-Item -Recurse -Force x'
bash_case block 'powershell -ExecutionPolicy Bypass Remove-Item -Recurse x'
bash_case block "pwsh -c \"iex 'Remove-Item -Recurse x'\""
bash_case block "pwsh -c \"Invoke-Expression 'rm -rf x'\""
bash_case block 'echo Remove-Item -Recurse x | powershell'
bash_case block 'echo rm -rf x | cmd'
bash_case block 'powershell'
bash_case block 'cmd'
bash_case block 'cmd /c"rm -rf x"'
bash_case block 'at now <<< "rm -rf x"'
bash_case block 'echo "rm -rf x" | at now'
bash_case allow 'powershell -File build.ps1'
bash_case allow 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Date"'
bash_case allow "pwsh -c \"iex 'Get-Date'\""
bash_case allow 'cmd /c dir'
bash_case allow 'rmdir -p build'
bash_case allow 'at -f x.sh < /dev/null'
bash_case allow 'echo hi | cat'

echo "Globs, braces, file operands and search"
bash_case block 'cat [.]env'
bash_case block 'cat [.]e*'
bash_case block 'cat .{env,x}'
bash_case block 'cat {.env,README.md}'
bash_case block 'cat .e{n,x}v'
bash_case block 'grep --regex=x .env'
bash_case block 'sed --expr=p .env'
bash_case block 'nvim .env'
bash_case block 'findstr x .env'
bash_case block 'certutil -encode .env x'
bash_case block 'ln -s .env x'
bash_case block 'xz -c .env'
bash_case block 'r{m,} -rf x'
bash_case block '{rm,-rf,x}'
bash_case block '/bin/[r]m -rf x'
bash_case block '[r]m -rf x'
bash_case block '/usr/bin/[g]it reset --hard'
# Known false positive: a command word with a glob is blocked, even when it is a script name.
bash_case block './run-*.sh'
bash_case allow '{echo,hi}'
bash_case allow '{a,b}.txt'
bash_case allow '[ -f x ] && echo ok'
bash_case allow '[[ -f x ]] && echo ok'
bash_case allow 'cat {README.md,docs}'
bash_case allow 'cat [.]x'
bash_case allow 'grep --regex=x README.md'
bash_case allow 'sed --expr=p README.md'
bash_case allow 'ln -s README.md link'
bash_case allow 'xz -c README.md'
grep_case block .env
grep_case block 'config/.env.local'
grep_case allow docs
grep_case allow README.md
path_case block Read '.env.'
path_case block Read '.env '
path_case block Read '.env::$DATA'
path_case block Create 'Assets/Foo.uasset.'
path_case block Create 'Assets/Foo.uasset::$DATA'
path_case block Edit 'Assets/Foo.uasset '
path_case allow Create 'Assets/Foo.uasset.txt'
path_case allow Create 'Assets/Foo.umap.bak'

echo "find, git, chmod, rm and NUL bytes"
bash_case block 'find . -name .env -exec cat {} +'
bash_case block "find . -name '.env' -print0 | xargs -0 cat"
bash_case allow 'find . -name .env -print'
bash_case allow 'find . -name "*.md" -print | sort'
bash_case block 'git reset --ha'
bash_case block 'git clean --fo -d'
bash_case block 'git push --mirror origin'
bash_case allow 'git clean --dry-run'
bash_case block 'chmod 1777 x'
bash_case block 'chmod 2777 x'
bash_case block 'chmod 4777 x'
bash_case block 'chmod 7777 x'
bash_case allow 'chmod 1755 run.sh'
bash_case block 'rm -r -fo build'
bash_case block 'rm -r -FORCE build'
bash_case allow 'rm -Force file.txt'
bash_case allow 'rm -LiteralPath x -Force'
bash_case allow 'rm -literalpath x -force'
bash_case allow 'rm -Filter "*.tmp" -Force'
bash_case block 'rm -literalpath x -recurse -force'
bash_case block 'rm -Re -Force build'
bash_case block 'rm -rfvx build'
bash_case block 'rm -{r,f} build'
bash_case block 'coproc { rm -rf x; }'
bash_case block 'coproc NAME { rm -rf x; }'
bash_case allow 'coproc { echo hi; }'
expect block 'NUL byte inside a command word' '{"tool_name":"Execute","tool_input":{"command":"rm\u0000 -rf x"}}'

echo "Nested braces, NUL escapes, .env probe names and special chmod bits"
bash_case block 'r{m,{x,y}} -rf target'
bash_case block '{rm,{-rf,x}} target'
bash_case block '{r{m,},x} -rf target'
bash_case block 'cat .{x,{env,y}}'
bash_case block 'cat {README.md,{.env,y}}'
bash_case block "\$'rm\\0suffix' -rf target"
bash_case block "\$'rm\\x00suffix' -rf target"
bash_case block "\$'rm\\000suffix' -rf target"
bash_case block "\$'rm\\400suffix' -rf target"
bash_case block "\$'rm\\x00' -rf target"
bash_case block "\$'rm\\0\\'x' -rf target"
bash_case block "\$'rm\\c@suffix' -rf target"
bash_case block "\$'rm\\c\`suffix' -rf target"
bash_case allow "echo \$'ab\\0cd'"
bash_case allow "echo \$'ab\\x0cd'"
bash_case allow '{echo,{hi,there}}'
bash_case allow 'echo {a{b,c}}'
bash_case block "$(printf '{%.0s' $(seq 1 1000))a,b} x"
bash_case block '{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b} x'
bash_case allow '{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b} x'
bash_case block 'cat .[e]nv.local'
bash_case block 'cat .[e]nv.example'
bash_case block 'cat .[e]nv.production'
bash_case block 'cat .[e]nv.[t]est'
bash_case block 'cat .[e]nv.stag*'
bash_case allow 'cat .[g]itignore'
bash_case block 'chmod 3777 x'
bash_case block 'chmod 5777 x'
bash_case block 'chmod 6777 x'
bash_case allow 'chmod 644 README.md'

echo "Brace expansion in every word, and sequences"
bash_case block 'rm --{recursive,force} target'
bash_case block 'rm --{recurs,forc} target'
bash_case block 'chmod {7,6}77 target'
bash_case block 'chmod 7{7..7}7 target'
bash_case block 'r{m..m} -rf target'
bash_case block 'r{m..m..1} -rf target'
bash_case block 'git {reset,status} --hard'
bash_case block 'echo x > .{env,x}'
bash_case block 'echo x > {.env,x}'
bash_case block 'echo {a,b} {1..5000}'
bash_case block 'echo {1..5000}'
bash_case block 'echo {1..99999999999}'
bash_case allow 'rm "--{recursive,force}" target'
bash_case allow 'chmod "{7,6}77" target'
bash_case allow 'chmod {6,4}77 x'
bash_case allow 'rm --{interactive,verbose} build.txt'
bash_case allow 'echo r{m..m}'
bash_case allow 'echo {1..4095} > /dev/null'
bash_case allow 'echo {1..10..3}'
bash_case allow 'echo {a..e..2}'
bash_case allow 'echo {a..5}'
bash_case allow 'echo {-03..1}'
bash_case allow 'echo "{rm,-rf}"'
bash_case allow 'echo {echo,hi}'

echo "Probe names with glob and bracket patterns"
bash_case block "find . -name '[.x]env' -exec cat {} +"
bash_case block "find . -name '*' -exec cat {} +"
bash_case block "find . -name '?env' -exec cat {} +"
bash_case block "find . -name '*.*' -print | xargs cat"
bash_case block 'cat [.]env.local'
bash_case block 'echo x > [.]env'
# Known false positive: a find -name glob that can match .env is blocked with a pipe.
bash_case block "find . -name '*.*' -print | sort"
bash_case allow "find . -name '*.sh' -exec cat {} +"
bash_case allow 'cat docs/*.md'
bash_case allow 'cat ?env'
bash_case allow 'cat *env'
bash_case allow 'cat *'
bash_case allow "find . -name '[.x]nv' -print"
bash_case allow 'echo x > [.]envx'
bash_case allow "find . -name '*' -print"
bash_case allow "find . -name '*.md' -exec cat {} +"

echo "Heredoc delimiters and bodies"
bash_case block $'cat <<EOF\n\'$(sudo id)\'\nEOF'
bash_case block $'cat <<$\'EOF\'\nbody\nEOF\nrm -rf build'
bash_case block $'cat <<$\'EOF\'\nx\nEOF\necho "a\nb" ; sudo id'
bash_case block $'cat <<EOF\n`sudo id`\nEOF'
bash_case block $'cat <<\\EOF\nx\nEOF\necho "a\nb" ; sudo id'
bash_case block $'cat <<"EOF"\nx\nEOF\necho "a\nb" ; sudo id'
bash_case block $'cat <<\'EOF\'\nx\nEOF\necho "a\nb" ; sudo id'
bash_case block $'cat <<$\'E\\x4fF\'\nx\nEOF\necho "a\nb" ; sudo id'
# Known false positive: a quoted heredoc body is checked as commands, so a $( ) outside single
# quotes in it is blocked, although the shell does not run it for cat.
bash_case block $'cat <<"EOF"\n$(sudo id)\nEOF'
bash_case block $'cat <<EOF\n# $(sudo id)\nEOF'
bash_case allow $'cat <<$\'EOF\'\n\'$(sudo id)\'\nEOF'
bash_case allow $'cat <<\'EOF\'\n\'$(sudo id)\'\nEOF'
bash_case allow $'cat <<\\EOF\n\'$(sudo id)\'\nEOF'
bash_case allow $'cat <<$\'EOF\'\nbody\nEOF\necho done'
bash_case allow $'cat <<EOF\nit\'s fine\nEOF\necho done'
# An unquoted body runs $( ), so a << in its text is not a heredoc opener, and the $( ) is checked.
bash_case block $'cat <<EOF\ntext <<\'$(sudo id)\nEOF'
bash_case block $'cat <<EOF\ntext <<\'$(echo x; sudo id)\nEOF'
bash_case allow $'cat <<EOF\ntext <<\'x\'\nEOF'
bash_case allow $'cat <<EOF\ntext <<\'$(echo hi)\nEOF'
# The quoted braces and commas of a quoted delimiter are literal, so the terminator matches.
bash_case block $'cat <<\'E{O}F\'\nx\nE{O}F\necho "a\nb"; sudo id'
bash_case block $'cat <<\'E,F\'\nx\nE,F\necho "a\nb"; sudo id'
bash_case block $'cat <<E\\{O\\}F\nx\nE{O}F\necho "a\nb"; sudo id'
bash_case allow $'cat <<\'E{O}F\'\nx\nE{O}F\necho ok'
bash_case allow $'cat <<\'E,F\'\nx\nE,F\necho ok'

# A backslash-newline in the delimiter is a line continuation, which bash removes, also inside
# double quotes, so the delimiter is EOF. The terminator then matches, and the commands after it
# are checked.
bash_case block $'cat <<E\\\nOF\nx\nEOF\necho "a\nb"; sudo id'
bash_case block $'cat <<"E\\\nOF"\nx\nEOF\necho "a\nb"; sudo id'
bash_case block $'cat <<E\\\nOF\n$(sudo id)\nEOF'
bash_case block $'cat <<-E\\\nOF\n\tx\n\tEOF\necho "a\nb"; sudo id'
bash_case allow $'cat <<E\\\nOF\nx\nEOF\necho "a\nb"; echo hi'
bash_case allow $'cat <<-E\\\nOF\n\tx\n\tEOF\necho "a\nb"; echo hi'

echo "Attached and clustered command options of wrappers"
bash_case block "script -c'rm -rf target' /dev/null"
bash_case block "script -qc'rm -rf target' /dev/null"
bash_case block "script -qc 'rm -rf target' /dev/null"
bash_case block "flock -c'rm -rf target' /tmp/lock"
bash_case block "flock -sc'rm -rf target' /tmp/lock"
bash_case block "flock /tmp/lock -c'rm -rf target'"
bash_case block "flock -w 5 -c'rm -rf target' /tmp/lock"
bash_case block "su -lc 'rm -rf target'"
bash_case block "su -c'rm -rf target'"
bash_case block "runuser -lc'rm -rf target' root"
bash_case block "script --command='rm -rf target' /dev/null"
bash_case allow "script -c'echo hi' /dev/null"
bash_case allow "script -qc 'echo hi' /dev/null"
bash_case allow "flock -c 'echo ok' /tmp/lock"
bash_case allow "flock -c'echo ok' /tmp/lock"
bash_case allow "su -lc 'echo ok'"
bash_case allow "runuser -u root -c'echo ok'"
bash_case allow "runuser -uc'rm -rf target' root"
# Unambiguous prefixes of the long command option are read as it, with or without =.
bash_case block "su --comm 'rm -rf target'"
bash_case block "su --c 'rm -rf target'"
bash_case block "su --session-command 'rm -rf target'"
bash_case block "su --sess 'rm -rf target'"
bash_case block "flock --comm='rm -rf target' /tmp/lock"
bash_case block "script --comm='rm -rf target' /dev/null"
bash_case allow "su --comm 'echo ok'"
bash_case allow "flock --comm='echo ok' /tmp/lock"
bash_case allow "su --shell /bin/sh"
bash_case allow "su --supp-group staff"

# Every command option of a wrapper is checked, not only the first, since util-linux uses the last.
bash_case block "script -c true -c 'rm -rf target' /dev/null"
bash_case block "su -c true -c 'rm -rf target'"
bash_case block "su -c 'echo ok' --command='rm -rf target'"
bash_case block "flock /tmp/lock -c true -c 'rm -rf target'"
bash_case block "runuser -c'echo ok' -c 'rm -rf target'"
bash_case block "su -c true root -c 'rm -rf target'"
bash_case block "script -c true /dev/null -c 'rm -rf target'"
bash_case allow "script -c 'echo ok' -c 'echo hi' /dev/null"
bash_case allow "su -c 'echo ok' --command='echo hi'"
# A command option after the first operand is read too, since GNU getopt permutes the arguments.
bash_case block "script /dev/null -c 'rm -rf target'"
bash_case block "runuser root -c 'rm -rf target'"
bash_case allow "script /dev/null -c 'echo ok'"
bash_case allow "runuser root -c 'echo ok'"
bash_case allow "su -c 'echo ok'"
bash_case allow "runuser -l root -c 'echo ok'"

echo "Long option prefixes"
bash_case block 'grep --reg x .env'
bash_case block 'grep --reg=x .env'
bash_case block 'sed --exp=p .env'
bash_case block 'sed --e p .env'
bash_case block 'sed --fi .env README.md'
bash_case allow 'grep --recursive foo src'
bash_case allow "sed --in-place 's/a/b/' file.txt"
bash_case allow 'grep --rec foo src'
bash_case allow 'grep --reg=x README.md'
bash_case allow 'sed --e p README.md'
bash_case allow 'grep --file=patterns.txt README.md'

echo "Size and time limits"
# Over the 256 KB shell-text budget, which is checked before the text is parsed.
big=""; printf -v big '%*s' 300000 ''; big="${big// /a}"
big_case block "a 300 KB word" "echo $big"
# Over the 5000 simple-command budget.
chain=""; for ((i = 0; i < 6000; i++)); do chain+="t;"; done
bash_case block "${chain}echo x"
# Under both budgets: 1500 commands and a 40 KB word.
chain=""; for ((i = 0; i < 1500; i++)); do chain+="true;"; done
bash_case allow "${chain}echo x"
big=""; printf -v big '%*s' 40000 ''; big="${big// /a}"
bash_case allow "echo $big"
# Wrappers run their operands as shell text, and each level checks the rest again. The check
# stops at 15 seconds and blocks, so the guard returns before the hook timeout.
wraps=""; for ((i = 0; i < 1500; i++)); do wraps+="watch "; done
bash_case block "${wraps}echo x"

echo "Payload shape, byte budget and timer start"
# A payload that is not one tool call with a string tool_name cannot be checked, so it is blocked.
expect block "empty payload" ""
expect block "truncated payload" '{"tool_name":"Bash","tool_input":{"command":"rm -rf audit-target"}'
expect block "two tool calls in one payload" "$(jq -cn '{tool_name: "Bash", tool_input: {command: "echo x"}}')$(jq -cn '{tool_name: "Bash", tool_input: {command: "echo y"}}')"
expect block "payload is an array" '[{"tool_name":"Bash","tool_input":{"command":"echo x"}}]'
expect block "no tool name" '{"hook_event_name":"PreToolUse","tool_input":{"command":"rm -rf audit-target"}}'
expect block "empty tool name" '{"tool_name":"","tool_input":{"command":"echo x"}}'
# A field of the wrong type fails its read, so the call is blocked rather than read as empty.
expect block "tool_input is a string" '{"tool_name":"Bash","tool_input":"rm -rf audit-target"}'
expect block "command is a number" '{"tool_name":"Bash","tool_input":{"command":5}}'
expect block "file_path is an object" '{"tool_name":"Read","tool_input":{"file_path":{"x":1}}}'
# A missing command leaves nothing to run, and a tool outside the checked set is not read.
expect allow "Bash without a command" '{"tool_name":"Bash","tool_input":{}}'
expect allow "Glob call" '{"tool_name":"Glob","tool_input":{"pattern":"*"}}'
# 70,000 emoji are 280,000 bytes but 70,002 characters, so only a byte count blocks them. The case
# runs under a UTF-8 locale, since under C a character count gives the same number as a byte count.
# The block must come from the byte budget, whose message names 256 KB.
emoji=""; printf -v emoji '%*s' 70000 ''; emoji="${emoji// /🙂}"
emoji_payload="$(printf '%s' "# $emoji" | jq -Rsc '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: .}}')"
utf8_locale=""
for l in C.UTF-8 C.utf8 en_US.UTF-8; do
  if [ "$(LC_ALL=$l bash -c 'x="🙂"; echo ${#x}' 2>/dev/null)" = 1 ]; then utf8_locale="$l"; break; fi
done
if [ -z "$utf8_locale" ]; then
  fail=$((fail + 1)); echo "FAIL: no UTF-8 locale is installed, so the emoji byte budget cannot be tested"
else
  err="$(printf '%s' "$emoji_payload" | LC_ALL="$utf8_locale" bash "$HERE/run-hook.sh" guard-destructive.sh 2>&1 >/dev/null)"
  got=$?
  case "$err" in
    *"256 KB"*) verdict block "70,000 emoji, over 256 KB in bytes, under $utf8_locale" "$got" ;;
    *) fail=$((fail + 1)); echo "FAIL: 70,000 emoji under $utf8_locale did not hit the byte budget, exit $got: $err" ;;
  esac
fi
# A byte count that fails must block the call. This wc stand-in fails the way wc does when it
# cannot read its input, so the 280 KB payload must not pass with a count of 0.
( wc() { command wc "$@" </tmp; }; export -f wc; printf '%s' "$emoji_payload" | bash "$HERE/run-hook.sh" guard-destructive.sh ) >/dev/null 2>&1
verdict block "a byte count that fails" "$?"
# A failing sleep stops the timer from starting, so the call is blocked rather than checked without a limit.
jq -cn '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: "echo x"}}' | (sleep() { return 127; }; export -f sleep; bash "$HERE/run-hook.sh" guard-destructive.sh) >/dev/null 2>&1
got=$?
if [ "$got" = 2 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: expected block, exit was $got: a failing sleep"; fi

echo "Adapter framing, rewrite failures and Factory tool names"
# The adapter reads the whole payload before it rewrites it, so trailing data blocks the call.
expect block "one tool call followed by a number" '{"hook_event_name":"PreToolUse","tool_name":"Execute","tool_input":{"command":"echo hi"}} 5'
expect block "one tool call followed by invalid JSON" '{"hook_event_name":"PreToolUse","tool_name":"Execute","tool_input":{"command":"echo hi"}} trailing-invalid-json'
# A rewrite that fails stops the hook, so the Execute payload never reaches the guard unchecked.
# The command is harmless, so the guard would allow it, and only the adapter's exit can block it.
adapter_block "rewrite fails, as with a broken jq" guard-destructive.sh "$(jq -cn '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: "echo hi"}}')" "could not be rewritten" "$FAIL_PATH"
# The guard accepts Factory's tool names too, for a call that reaches it without run-hook.sh.
direct block "Execute with rm -rf" "$(jq -cn '{hook_event_name: "PreToolUse", tool_name: "Execute", tool_input: {command: "rm -rf audit-target"}}')"
direct block "Create of .env" '{"hook_event_name":"PreToolUse","tool_name":"Create","tool_input":{"file_path":".env","content":"x"}}'
direct block "Create of a .uasset" '{"hook_event_name":"PreToolUse","tool_name":"Create","tool_input":{"file_path":"Content/Test.uasset","content":"x"}}'
direct allow "Create of docs/notes.md" '{"hook_event_name":"PreToolUse","tool_name":"Create","tool_input":{"file_path":"docs/notes.md","content":"x"}}'

echo "Read failures, empty payloads, byte counts and the bash 3.2 branch"
harmless='{"hook_event_name":"PreToolUse","tool_name":"Execute","tool_input":{"command":"echo hi"}}'
# A read that fails blocks the call, even when the partial output is one complete harmless call.
# The adapter's own message must be named, since the guard also fails on the stand-in cat.
adapter_block "the adapter's read fails after a complete call" guard-destructive.sh "$harmless" "run-hook: the hook payload could not be read" "$READ_FAIL_PATH"
guard_case block "the guard's read fails after a complete call" "$HERE/guard-destructive.sh" "$harmless" "$READ_FAIL_PATH" "could not be read"
# A field that cannot be read stops the adapter, so the call is never read as if the field were
# empty. Each stand-in fails one read, and the adapter's message must be on stderr, so a block from
# the guard would not pass for it.
field_msg="run-hook: a field of the hook payload could not be read"
session_start='{"hook_event_name":"SessionStart","session_id":"s1","calling_session_id":"c1"}'
task_call='{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":{"subagent_type":"ccgs-tester","description":"check"}}'
stop_call='{"hook_event_name":"SubagentStop","task_name":"check"}'
adapter_block "the adapter's event read fails" guard-destructive.sh "$harmless" "$field_msg" "$EVENT_FAIL_PATH"
adapter_block "the adapter's session read fails" guard-destructive.sh "$harmless" "$field_msg" "$SESSION_FAIL_PATH"
adapter_block "the adapter's tool name read fails" guard-destructive.sh "$harmless" "$field_msg" "$TOOL_FAIL_PATH"
adapter_block "the adapter's calling session read fails" guard-destructive.sh "$session_start" "$field_msg" "$CALLER_FAIL_PATH"
adapter_block "the adapter's Task type read fails" guard-destructive.sh "$task_call" "$field_msg" "$SUBTYPE_FAIL_PATH"
adapter_block "the adapter's Task description read fails" guard-destructive.sh "$task_call" "$field_msg" "$DESC_FAIL_PATH"
adapter_block "the adapter's SubagentStop read fails" guard-destructive.sh "$stop_call" "$field_msg" "$TASK_FAIL_PATH"
# A Task call whose tool input is not an object has no type to read, so it passes, as before.
expect allow "a Task call whose tool input is a string" '{"hook_event_name":"PreToolUse","tool_name":"Task","tool_input":"x"}'
# The session id is filtered by tr. A failed tr must stop the hook, not leave the id empty.
adapter_block "the session id filter fails" guard-destructive.sh "$harmless" "run-hook: the session id could not be filtered" "$SESSION_TR_FAIL_PATH"
# Without jq the adapter rewrites with sed. A failed sed must stop the hook, not pass a partial payload.
adapter_block "a rewrite fails without jq" guard-destructive.sh "$harmless" "could not be rewritten" "$NOJQ_SED_FAIL_PATH"
# The adapter finds its own directory with dirname. A failed dirname must stop the hook, not run a missing script.
adapter_block "the adapter's directory cannot be found" guard-destructive.sh "$harmless" "run-hook: the hook directory could not be found" "$DIRNAME_FAIL_PATH"
# A tr that fails on the payload read blocks the call too.
guard_case block "the guard's payload tr fails" "$HERE/guard-destructive.sh" "$harmless" "$TR_READ_FAIL_PATH" "could not be read"
# An empty payload is not one JSON object, so the adapter rejects it before any script runs.
adapter_block "an empty payload, rejected by the adapter" guard-destructive.sh "" "not one JSON object"
adapter_block "an empty payload to a script other than the guard" notify.sh "" "not one JSON object"
# A byte count is read as decimal, so 08 is 8, not an octal error. A count too large for the
# arithmetic blocks the call instead of wrapping to a small number. An octal error prints to
# stderr without blocking, so the allowed call must also leave stderr empty.
err="$( (wc() { printf '%s\n' 08; }; export -f wc; printf '%s' "$harmless" | bash "$HERE/run-hook.sh" guard-destructive.sh) 2>&1 >/dev/null )"
verdict allow "a byte count of 08, read as decimal" "$?"
if [ -n "$err" ]; then fail=$((fail + 1)); echo "FAIL: a byte count of 08 printed an error: $err"; fi
err="$( (wc() { printf '%s\n' 18446744073709551616; }; export -f wc; printf '%s' "$harmless" | bash "$HERE/run-hook.sh" guard-destructive.sh) 2>&1 >/dev/null )"
verdict block "a byte count of 2^64, which would wrap to 0" "$?"
case "$err" in *"could not be measured"*) ;; *) fail=$((fail + 1)); echo "FAIL: stderr does not name the byte count: a byte count of 2^64" ;; esac
# The bash 3.2 branch lowercases the name with tr, and a failed tr blocks the call.
bash32="$extra_dir/fallback/guard-destructive.sh"
guard_case block "the bash 3.2 branch, Read of .ENV" "$bash32" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"./.ENV"}}'
guard_case allow "the bash 3.2 branch, Read of README.md" "$bash32" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"README.md"}}'
guard_case block "the bash 3.2 branch, a failed lowercase" "$bash32" '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"./.ENV"}}' "$TR_CASE_FAIL_PATH" "could not be lowercased"

echo "Native Windows jq output (CRLF)"
bash_case block 'rm -rf build' "$CRLF_PATH"
bash_case block 'git -C . reset --hard' "$CRLF_PATH"
bash_case allow 'git status' "$CRLF_PATH"
path_case block Read .env "$CRLF_PATH"

echo "test-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
