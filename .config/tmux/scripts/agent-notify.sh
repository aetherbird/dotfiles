#!/usr/bin/env bash
# agent-notify.sh — title icons + ding for agent CLI windows.
# Wired from the "Agent alerts" section of ~/.tmux.conf (tmux hooks).
#
#   bell  <window_id>   window rang BEL           -> needs attention (🔔)
#   done  <window_id>   agent went quiet / exited -> finished        (✅)
#   clear <window_id>   window regained focus     -> restore plain title
#
# Sounds come from sound-theme-freedesktop via paplay (PipeWire) with an
# ffplay fallback. Set @agent-alert-sound to "off" to silence the dings.
set -u

SND=/usr/share/sounds/freedesktop/stereo
ICON_BELL="🔔"
ICON_DONE="✅"
GRACE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tmux-agent-watch/grace"

play() {
    [ -r "$SND/$1" ] || return 0
    if command -v paplay >/dev/null 2>&1; then
        paplay --volume=44000 "$SND/$1" >/dev/null 2>&1 &
    elif command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -loglevel quiet "$SND/$1" >/dev/null 2>&1 &
    fi
}

sound_allowed() {
    [ "$(tmux show-options -gv @agent-alert-sound 2>/dev/null)" = "off" ] && return 1
    # no startup chorus: watcher touches $GRACE_FILE when it boots; keep the
    # first minute quiet (long-idle agent windows get their ✅ without dings)
    if [ -f "$GRACE_FILE" ]; then
        age=$(( $(date +%s) - $(stat -c %Y "$GRACE_FILE" 2>/dev/null || echo 0) ))
        [ "$age" -lt 60 ] && return 1
    fi
    return 0
}

cmd="${1:-}"
win="${2:-}"
[ -n "$win" ] || exit 0
name="$(tmux display-message -p -t "$win" '#{window_name}' 2>/dev/null)" || exit 0
[ -n "$name" ] || exit 0
base="${name#"$ICON_BELL" }"
base="${base#"$ICON_DONE" }"

case "$cmd" in
bell | done)
    # the user is already looking at this window -> nothing to signal
    [ "$(tmux display-message -p -t "$win" '#{window_active}')" = "1" ] && exit 0
    if [ "$cmd" = bell ]; then
        icon="$ICON_BELL" snd="bell.oga"
    else
        icon="$ICON_DONE" snd="complete.oga"
    fi
    if [ "$name" != "$icon $base" ]; then
        # renaming switches automatic-rename off; remember the window's
        # original setting so `clear` can restore it (custom names survive)
        if [ -z "$(tmux show-options -wq -v -t "$win" @icon-autorename 2>/dev/null)" ]; then
            auto="$(tmux show-options -wq -v -t "$win" automatic-rename 2>/dev/null)"
            tmux set-option -wq -t "$win" @icon-autorename "${auto:-on}"
        fi
        tmux rename-window -t "$win" "$icon $base"
    fi
    [ "$cmd" = bell ] && tmux display-message -d 4000 "$icon $base needs attention" 2>/dev/null
    sound_allowed && play "$snd"
    ;;
clear)
    case "$name" in
    "$ICON_BELL "* | "$ICON_DONE "*)
        saved="$(tmux show-options -wq -v -t "$win" @icon-autorename 2>/dev/null)"
        tmux rename-window -t "$win" "$base"
        tmux set-option -wq -t "$win" automatic-rename "${saved:-on}"
        tmux set-option -wuq -t "$win" @icon-autorename
        ;;
    esac
    ;;
esac
