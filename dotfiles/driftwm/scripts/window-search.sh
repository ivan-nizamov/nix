#!/bin/sh

set -eu

XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

lookup_desktop() {
    id="$1"

    for dir in "$HOME/.local/share/applications" $(printf '%s' "$XDG_DATA_DIRS" | tr ':' ' '); do
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
seen_apps=$(mktemp)
trap 'rm -f "$display" "$lookup" "$seen_apps"' EXIT

wlrctl toplevel list | while IFS= read -r line; do
    app_id="${line%%: *}"
    title="${line#*: }"
    desktop=$(lookup_desktop "$app_id")
    app_name="${desktop%%	*}"
    rest="${desktop#*	}"
    icon="${rest%%	*}"
    desktop_id="${rest#*	}"

    if ! grep -Fxq "$app_id" "$seen_apps"; then
        if [ "$desktop_id" != "$app_id" ]; then
            printf '%s  [new]\0icon\x1f%s\n' "$app_name" "$icon" >> "$display"
            printf 'launch\t%s\t%s\n' "$desktop_id" "$app_name" >> "$lookup"
        fi
        printf '%s\n' "$app_id" >> "$seen_apps"
    fi

    printf '%s  %s\0icon\x1f%s\n' "$title" "$app_name" "$icon" >> "$display"
    printf '%s\t%s\n' "$app_id" "$title" >> "$lookup"
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
    *)
        sel_app_id=$(printf '%s' "$match" | cut -f1)
        sel_title=$(printf '%s' "$match" | cut -f2)
        exec wlrctl toplevel focus "app_id:$sel_app_id" "title:$sel_title"
        ;;
esac
