#!/bin/sh
# Runs the per-feature test files, each in its own process against its own
# isolated tmux server (test/lib.sh holds the fixture and the assertions).
# Files run concurrently; each file's output is buffered and printed whole,
# in the order the files were started, so two files never interleave.
#
#   sh test/run.sh                run every test/t-*.sh, several at a time
#   sh test/run.sh -j 1           run them one at a time
#   sh test/run.sh hooks next     run only t-hooks.sh and t-next.sh
#   KEEP=1 sh test/run.sh hold    leave that test's server running for inspection
set -u
DIR=$(cd "$(dirname "$0")" && pwd)

njobs=
while [ $# -gt 0 ]; do
  case $1 in
    -j)  [ $# -ge 2 ] || { echo "run.sh: -j needs a number" >&2; exit 1; }
         njobs=$2; shift 2 ;;
    -j*) njobs=${1#-j}; shift ;;
    --)  shift; break ;;
    -*)  echo "run.sh: unknown option: $1" >&2; exit 1 ;;
    *)   break ;;
  esac
done
if [ -z "$njobs" ]; then
  njobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
fi
case $njobs in
  ''|*[!0-9]*|0) echo "run.sh: -j wants a positive integer, not '$njobs'" >&2; exit 1 ;;
esac

if [ $# -eq 0 ]; then
  set -- "$DIR"/t-*.sh
  # An unmatched glob is left literal, and an empty suite is a failure, not a
  # run of nothing that passes.
  [ -f "$1" ] || { echo "run.sh: no test files in $DIR" >&2; exit 1; }
else
  n=$#
  for a in "$@"; do
    b=${a##*/}; b=${b%.sh}; b=${b#t-}
    f="$DIR/t-$b.sh"
    [ -f "$f" ] || { echo "run.sh: no such test: $a" >&2; exit 1; }
    set -- "$@" "$f"
  done
  shift "$n"
fi

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
trap 'rm -rf "$tmp"; exit 130' INT
trap 'rm -rf "$tmp"; exit 143' TERM HUP

# One line per test file: the queue the workers walk, indexed by line number.
list=$tmp/files
: > "$list"
files=0
for f in "$@"; do
  [ -f "$f" ] || continue
  files=$((files + 1))
  printf '%s\n' "$f" >> "$list"
done
[ "$files" -gt 0 ] || { echo "run.sh: no test files to run" >&2; exit 1; }

pass=0; fail=0; broken=0

report() { # report <index> <exit status>
  r_f=$(sed -n "${1}p" "$list"); r_b=${r_f##*/}; r_log=$tmp/log.$1
  printf '=== %s\n' "$r_b"
  cat "$r_log"
  # The summary line a file prints is the authority on its counts, but only its
  # exit status is the authority on whether it lived: a file that died after
  # printing "0 failed" has still failed.
  r_line=$(grep -E '^[0-9]+ passed, [0-9]+ failed$' "$r_log" | tail -1)
  if [ -z "$r_line" ]; then
    printf '  FAIL %s produced no summary line (exit %s)\n' "$r_b" "$2"
    broken=$((broken + 1))
    return 0
  fi
  r_p=$(printf '%s\n' "$r_line" | awk '{print $1}')
  r_m=$(printf '%s\n' "$r_line" | awk '{print $3}')
  pass=$((pass + r_p)); fail=$((fail + r_m))
  if [ "$2" -ne 0 ] && [ "$r_m" -eq 0 ]; then
    printf '  FAIL %s exited %s after reporting no failures\n' "$r_b" "$2"
    broken=$((broken + 1))
  fi
}

# A sliding window of at most $njobs files in flight. Their pids are held,
# oldest first, as "index:pid" words; the oldest is always the next one waited
# on and reported, so output arrives in the order the files were started.
started=0; finished=0; inflight=0; running=
while [ "$finished" -lt "$files" ]; do
  while [ "$started" -lt "$files" ] && [ "$inflight" -lt "$njobs" ]; do
    started=$((started + 1))
    file=$(sed -n "${started}p" "$list")
    sh "$file" > "$tmp/log.$started" 2>&1 &
    running="$running $started:$!"
    inflight=$((inflight + 1))
  done
  running=${running# }
  head=${running%% *}
  case $running in
    *' '*) running=${running#* } ;;
    *)     running= ;;
  esac
  wait "${head#*:}"; rc=$?
  inflight=$((inflight - 1)); finished=$((finished + 1))
  report "${head%%:*}" "$rc"
done

if [ "$files" -eq 1 ]; then plural=; else plural=s; fi
printf '\n%d file%s, %d passed, %d failed\n' "$files" "$plural" "$pass" "$fail"
[ "$fail" -eq 0 ] && [ "$broken" -eq 0 ] && exit 0
exit 1
