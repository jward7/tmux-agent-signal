#!/bin/sh
# `agent-signal list`, the tree the switcher popup renders.
# shellcheck source-path=SCRIPTDIR source=./lib.sh
. "$(dirname "$0")/lib.sh"
setup

hook "$P_API" UserPromptSubmit   # api: working (a marked window)
hook "$P_WEB2" Stop              # web: done   (a marked window; shell stays unmarked)

is "list has session, window and pane rows" "$("$AS" list | cut -f1 | sort -u | tr -d '\n')" "PSW"
ascii on   # single-byte marks, so index() measures columns and not bytes
is "window rows share one column for the index" "$("$AS" list | awk -F'\t' '$1 == "W" {print index($3, ":")}' | sort -u | wc -l | tr -d ' ')" 1
is "a marked and an unmarked window row align" "$("$AS" list | awk -F'\t' '$1 == "W" {print (substr($3, 1, 1) == " ")}' | sort -u | wc -l | tr -d ' ')" 2
ascii off

T rename-window -t "$W_WEB" ''
is "list survives an empty window name" "$("$AS" list 2>&1 | grep -c 'integer expression')" 0
T rename-window -t "$W_WEB" web

finish
