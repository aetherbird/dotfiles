#!/usr/bin/env bash
# agent-watch.sh — keep tmux silence monitoring pointed at agent CLI windows.
#
# tmux's monitor-silence is what turns "agent stopped streaming" into an
# alert, but it would be annoying on ordinary shells — so every tick this
# script:
#   * enables monitor-silence only on windows where the foreground command
#     is one of the agent CLIs (kimi, claude, codex, mariana, omp)
#   * flags an agent that exited back to a shell as finished (✅)
#   * clears stale 🔔/✅ icons once the window is actually being viewed
#
# Started from ~/.tmux.conf via `run-shell -b`; flock keeps a single
# instance across config reloads. Dies with the tmux server.
set -u

AGENTS='^(kimi|kimi-code|claude|codex|mariana|mariana-server|omp)$'
NOTIFY="$HOME/.config/tmux/scripts/agent-notify.sh"
state="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch"
mkdir -p "$state"
exec 9>"$state/lock"
# wait (not just try) so a restart racing the previous instance's shutdown
# takes over the lock instead of silently exiting watcherless
flock -w 30 9 || exit 0
: >"$state/grace"   # agent-notify.sh mutes dings for the first 60s

pref_silence() {
    local v
    v="$(tmux show-options -gv @agent-silence-secs 2>/dev/null)"
    [[ "$v" =~ ^[0-9]+$ ]] && printf '%s' "$v" || echo 45
}

declare -A seen seen_win pane_was win_agent armed
while :; do
    tmux info >/dev/null 2>&1 || exit 0
    SECS="$(pref_silence)"
    seen=()
    seen_win=()
    win_agent=()

    # pass 1: panes — which windows are running agents right now, and which
    # panes just lost their agent process (finished and dropped to a shell)
    while IFS='|' read -r wid pid cmd _wact _satt; do
        [ -n "${wid:-}" ] || continue
        seen["$pid"]=1
        if [[ "$cmd" =~ $AGENTS ]]; then
            st=agent
            win_agent["$wid"]=1
        else
            st=other
        fi
        if [ "${pane_was[$pid]:-}" = agent ] && [ "$st" = other ]; then
            "$NOTIFY" done "$wid" 2>/dev/null
        fi
        pane_was["$pid"]="$st"
    done < <(tmux list-panes -a -F '#{window_id}|#{pane_id}|#{pane_current_command}|#{window_active}|#{session_attached}' 2>/dev/null)

    # pass 2: windows — silence only on agent windows, icons cleared when
    # the window is the current one of an attached session (user is viewing)
    while IFS='|' read -r wid name wact satt act; do
        [ -n "${wid:-}" ] || continue
        seen_win["$wid"]=1
        if [ "$wact" = "1" ] && [ "$satt" != "0" ]; then
            case "$name" in
            "🔔 "* | "✅ "*) "$NOTIFY" clear "$wid" 2>/dev/null ;;
            esac
        fi
        if [ "${win_agent[$wid]:-}" = 1 ]; then
            # arm silence monitoring; re-arm only after fresh output so one
            # quiet episode alerts exactly once (tmux disarms on alert, and
            # re-arming an already-idle window would re-ding every cycle).
            # an uncleared 🔔/✅ icon means the episode already alerted.
            case "$name" in
            "🔔 "* | "✅ "*) ;;
            *)
                if [ "${armed[$wid]:-}" != "$act" ]; then
                    tmux set-option -wq -t "$wid" monitor-silence "$SECS"
                    armed["$wid"]="$act"
                fi
                ;;
            esac
        else
            [ "$(tmux show-options -w -v -t "$wid" monitor-silence 2>/dev/null || echo 0)" = "0" ] ||
                tmux set-option -wq -t "$wid" monitor-silence 0
            unset "armed[$wid]"
        fi
    done < <(tmux list-windows -a -F '#{window_id}|#{window_name}|#{window_active}|#{session_attached}|#{window_activity}' 2>/dev/null)

    # drop state for panes and windows that no longer exist
    for pid in "${!pane_was[@]}"; do
        [ -n "${seen[$pid]:-}" ] || unset "pane_was[$pid]"
    done
    for wid in "${!armed[@]}"; do
        [ -n "${seen_win[$wid]:-}" ] || unset "armed[$wid]"
    done

    sleep 8
done
