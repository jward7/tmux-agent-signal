#!/bin/sh
# `sync` against a fake Claude session registry ($HOME/.claude/sessions/*.json,
# each naming its pane as session_name:window_id.pane_id). HOME is pointed at
# a private directory on every call, never at the real one.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
HERE=$(dirname "$0"); . "$HERE/lib.sh"
setup

FAKE="$TMPDIR/home"; REG="$FAKE/.claude/sessions"; mkdir -p "$REG"
name() { T display -p -t "$1" '#{@agent_name}'; }
kind() { T display -p -t "$1" '#{@agent_kind}'; }

printf '{"tmux":"main:%s.%s","name":"foo"}\n'   "$W_API" "$P_API"  > "$REG/a.json"
# Stale: the right pane id, but a session or window it is no longer in.
printf '{"tmux":"other:%s.%s","name":"bar"}\n'  "$W_WEB" "$P_WEB"  > "$REG/b.json"
printf '{"tmux":"main:%s.%s","name":"baz"}\n'   "$W_API" "$P_WEB"  > "$REG/c.json"
# No name: still a Claude pane.
printf '{"tmux":"main:%s.%s"}\n'                "$W_WEB" "$P_WEB2" > "$REG/d.json"
# Not in tmux at all, and not JSON: both skipped without a fuss.
printf '{"tmux":"","name":"elsewhere"}\n'                          > "$REG/e.json"
printf 'not json\n'                                                > "$REG/f.json"

out=$(HOME=$FAKE "$AS" sync 2>&1); rc=$?
is "sync exits 0 silently"                         "$rc [$out]" "0 []"
is "sync names the pane from the registry"         "$(name "$P_API")" foo
is "sync marks the pane as claude"                 "$(kind "$P_API")" claude
is "an entry naming the wrong session or window is ignored" "$(name "$P_WEB")|$(kind "$P_WEB")" "|"
is "an entry without a name sets the kind"         "$(kind "$P_WEB2")" claude
is "an entry without a name sets no name"          "$(name "$P_WEB2")" ""
is "sync sets no pane state"                       "$(pst "$P_API")" ""
is "sync puts both claude panes in the summary"      "$(gsum)" "✳1 ✳2 "

hook "$P_API" UserPromptSubmit   # a single-pane window lists its pane once it has a state
is "list shows the registry name in the pane row"  "$(HOME=$FAKE "$AS" list | awk -F'\t' -v p="$P_API" '$1 == "P" && $2 == p' | grep -c foo)" 1

T set-option -up -t "$P_API" @agent_name
printf '{"source":"startup"}' | HOME=$FAKE TMUX_PANE=$P_API "$AS" hook SessionStart
is "SessionStart syncs the registry"               "$(name "$P_API")" foo

# Without jq the registry cannot be read: sync is a quiet no-op.
NOJQ=$(mktemp -d); for b in sh cat tmux awk sed grep tr head cut sort ls mkdir rmdir sleep id dirname; do ln -s "$(command -v "$b")" "$NOJQ/$b"; done
T set-option -up -t "$P_API" @agent_name; T set-option -up -t "$P_API" @agent_kind
T set-option -up -t "$P_WEB2" @agent_kind
out=$(HOME=$FAKE PATH=$NOJQ "$AS" sync 2>&1); rc=$?
is "sync without jq exits 0 silently"              "$rc [$out]" "0 []"
is "sync without jq names nothing"                 "$(name "$P_API")|$(kind "$P_API")|$(kind "$P_WEB2")" "||"
rm -rf "$NOJQ"

finish
