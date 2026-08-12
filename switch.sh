#!/usr/bin/env bash
#
# Install one of this repo's mouse variants as ~/.hammerspoon/init.lua.
#
#   ./switch.sh 4            install the MX Master 4 config
#   ./switch.sh 3s           install the MX Master 3S / 3 / 2S config
#   ./switch.sh              report which variant is currently active
#   ./switch.sh 4 --link     symlink instead of copy (see the warning below)
#
# COPY IS THE DEFAULT, ON PURPOSE.
#   macOS gates ~/Documents, ~/Desktop and ~/Downloads behind TCC. If this
#   checkout lives in one of those and Hammerspoon has not been granted Files
#   and Folders access to it, Hammerspoon cannot read through a symlink into
#   the checkout. init.lua then fails to load ENTIRELY, with no error message
#   and no alert: the tap never starts and hs.ipc never registers. Copying
#   sidesteps that, because the file ends up inside ~/.hammerspoon.
#
#   Use --link only when the checkout is somewhere Hammerspoon can read, and
#   verify afterwards that the startup alert actually appeared.
#
# Any pre-existing real init.lua is backed up, never overwritten in place.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.hammerspoon/init.lua"

variant_of_file() {
    # Echo the variant whose init.lua matches $1, else nothing.
    local f="$1" v
    for v in mx-master-4 mx-master-3s; do
        if [[ -f "$REPO/$v/init.lua" ]] && cmp -s "$f" "$REPO/$v/init.lua"; then
            echo "$v"
            return
        fi
    done
}

active_variant() {
    if [[ -L "$TARGET" ]]; then
        local dest
        dest="$(readlink "$TARGET")"
        case "$dest" in
            *mx-master-4/init.lua)  echo "mx-master-4 (symlink)"  ;;
            *mx-master-3s/init.lua) echo "mx-master-3s (symlink)" ;;
            *) echo "symlink to $dest" ;;
        esac
    elif [[ -f "$TARGET" ]]; then
        local v
        v="$(variant_of_file "$TARGET")"
        if [[ -n "$v" ]]; then
            echo "$v (copy)"
        else
            echo "a file that matches neither variant (locally modified?)"
        fi
    else
        echo "not installed"
    fi
}

MODE="copy"
ARGS=()
for a in "$@"; do
    case "$a" in
        --link) MODE="link" ;;
        --copy) MODE="copy" ;;
        *)      ARGS+=("$a") ;;
    esac
done

case "${ARGS[0]:-}" in
    4|mx4|mx-master-4)
        VARIANT="mx-master-4" ; LABEL="MX Master 4" ;;
    3s|3|2s|mx3s|mx-master-3s)
        VARIANT="mx-master-3s" ; LABEL="MX Master 3S / 3 / 2S" ;;
    "")
        echo "active: $(active_variant)"
        echo
        echo "usage: $0 {4|3s} [--link]"
        exit 0
        ;;
    -h|--help|help)
        sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *)
        echo "unknown variant: ${ARGS[0]}" >&2
        echo "usage: $0 {4|3s} [--link]" >&2
        exit 2
        ;;
esac

SRC="$REPO/$VARIANT/init.lua"
if [[ ! -f "$SRC" ]]; then
    echo "missing config: $SRC" >&2
    exit 1
fi

if [[ "$MODE" == "link" ]]; then
    case "$REPO/" in
        "$HOME"/Documents/*|"$HOME"/Desktop/*|"$HOME"/Downloads/*)
            echo "WARNING: this checkout is under a macOS TCC-protected folder." >&2
            echo "  $REPO" >&2
            echo "  Hammerspoon may be unable to read through the symlink, in which" >&2
            echo "  case init.lua will not load at all and nothing will be reported." >&2
            echo "  If the startup alert does not appear, re-run without --link." >&2
            echo >&2
            ;;
    esac
fi

mkdir -p "$HOME/.hammerspoon"

# Preserve anything that is not already one of our own installs.
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    if [[ -L "$TARGET" ]] || [[ -n "$(variant_of_file "$TARGET")" ]]; then
        rm -f "$TARGET"
    else
        BACKUP="$TARGET.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$TARGET" "$BACKUP"
        echo "backed up existing config to $BACKUP"
    fi
fi

if [[ "$MODE" == "link" ]]; then
    ln -sfn "$SRC" "$TARGET"
    echo "linked $LABEL"
    echo "  $TARGET -> $SRC"
else
    cp "$SRC" "$TARGET"
    echo "installed $LABEL"
    echo "  $SRC -> $TARGET"
    echo "  (copy: re-run this script after editing the repo copy)"
fi

# Reload a running Hammerspoon if the CLI is available (hs.ipc is loaded by
# both configs). Otherwise fall back to the menu bar.
if command -v hs >/dev/null 2>&1 && echo 'hs.reload()' | hs >/dev/null 2>&1; then
    echo "reloaded Hammerspoon"
else
    echo "now reload Hammerspoon: menu bar hammer icon, Reload Config"
fi
