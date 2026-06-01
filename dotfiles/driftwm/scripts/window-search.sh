#!/bin/sh

set -eu

XDG_DATA_DIRS="${XDG_DATA_DIRS:-/run/current-system/sw/share:/usr/local/share:/usr/share}"

desktop_dir() {
    case "$1" in
        */applications) printf '%s\n' "$1" ;;
        *) printf '%s/applications\n' "$1" ;;
    esac
}

lookup_desktop() {
    id="$1"

    for dir in "$HOME/.local/share/applications" $(printf '%s' "$XDG_DATA_DIRS" | tr ':' ' '); do
        dir=$(desktop_dir "$dir")
        [ -d "$dir" ] || continue
        for f in "$dir/$id.desktop" "$dir"/*"$id"*.desktop; do
            [ -f "$f" ] || continue
            name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
            icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
            desktop_id=${f##*/}
            desktop_id=${desktop_id%.desktop}
            [ -n "$name" ] && printf '%s\t%s\t%s' "$name" "${icon:-$id}" "$desktop_id" && return
        done
    done

    for dir in "$HOME/.local/share/applications" $(printf '%s' "$XDG_DATA_DIRS" | tr ':' ' '); do
        dir=$(desktop_dir "$dir")
        [ -d "$dir" ] || continue
        f=$(grep -rl "^StartupWMClass=$id$" "$dir"/*.desktop 2>/dev/null | head -1)
        if [ -n "$f" ]; then
            name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
            icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
            desktop_id=${f##*/}
            desktop_id=${desktop_id%.desktop}
            [ -n "$name" ] && printf '%s\t%s\t%s' "$name" "${icon:-$id}" "$desktop_id" && return
        fi
    done

    printf '%s\t%s\t%s' "$id" "$id" "$id"
}

display=$(mktemp)
lookup=$(mktemp)
seen_desktops=$(mktemp)
trap 'rm -f "$display" "$lookup" "$seen_desktops"' EXIT

append_launcher() {
    f="$1"
    desktop_id=${f##*/}
    desktop_id=${desktop_id%.desktop}

    grep -Fxq "$desktop_id" "$seen_desktops" 2>/dev/null && return

    name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
    icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
    [ -n "$name" ] || return

    printf '%s  [new]\0icon\x1f%s\n' "$name" "${icon:-$desktop_id}" >> "$display"
    printf 'launch\t%s\n' "$desktop_id" >> "$lookup"
    printf '%s\n' "$desktop_id" >> "$seen_desktops"
}

for dir in "$HOME/.local/share/applications" $(printf '%s' "$XDG_DATA_DIRS" | tr ':' ' '); do
    dir=$(desktop_dir "$dir")
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue
        append_launcher "$f"
    done
done

wlrctl toplevel list | while IFS= read -r line; do
    app_id="${line%%: *}"
    title="${line#*: }"
    desktop=$(lookup_desktop "$app_id")
    app_name="${desktop%%	*}"
    rest="${desktop#*	}"
    icon="${rest%%	*}"

    printf '%s  %s\0icon\x1f%s\n' "$title" "$app_name" "$icon" >> "$display"
    printf 'window\t%s\t%s\n' "$app_id" "$title" >> "$lookup"
done

[ -s "$display" ] || exit 0

selected=$(fuzzel --dmenu \
    --prompt="Window/App: " \
    --no-run-if-empty \
    --index \
    < "$display")

[ -z "$selected" ] && exit 0

line_num=$((selected + 1))
match=$(sed -n "${line_num}p" "$lookup")
sel_kind=$(printf '%s' "$match" | cut -f1)

case "$sel_kind" in
    launch)
        sel_desktop_id=$(printf '%s' "$match" | cut -f2)
        exec gtk-launch "$sel_desktop_id"
        ;;
    window)
        sel_app_id=$(printf '%s' "$match" | cut -f2)
        sel_title=$(printf '%s' "$match" | cut -f3)
        exec wlrctl toplevel focus "app_id:$sel_app_id" "title:$sel_title"
        ;;
    *)
        exit 0
        ;;
esac
