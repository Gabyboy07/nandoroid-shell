#!/usr/bin/env bash
# presets.sh - manage shell config presets
# Usage:
#   presets.sh --save <name> [description]
#   presets.sh --remove <name>
#   presets.sh --apply <name>

CONFIG_DIR="$HOME/.config/nandoroid"
CONFIG_FILE="$CONFIG_DIR/config.json"
PRESETS_DIR="$CONFIG_DIR/presets"

mkdir -p "$PRESETS_DIR"

action="$1"
name="$2"

if [ -z "$name" ]; then
    echo "Error: missing preset name" >&2
    exit 1
fi

case "$action" in
    --save)
        description="$3"
        jq 'del(._presetMeta)' "$CONFIG_FILE" > "$PRESETS_DIR/${name}.json"
        if [ -n "$description" ]; then
            jq --arg desc "$description" '._presetMeta = {"description": $desc}' \
                "$PRESETS_DIR/${name}.json" > "$PRESETS_DIR/${name}.json.tmp" \
                && mv "$PRESETS_DIR/${name}.json.tmp" "$PRESETS_DIR/${name}.json"
        fi
        ;;
    --remove)
        rm -f "$PRESETS_DIR/${name}.json"
        ;;
    --apply)
        preset_file="$PRESETS_DIR/${name}.json"
        if [ ! -f "$preset_file" ]; then
            echo "Error: preset not found: $name" >&2
            exit 1
        fi
        jq -s '.[0] * .[1] | del(._presetMeta)' "$CONFIG_FILE" "$preset_file" \
            > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

        matugen_enabled=$(jq -r '.appearance.background.matugen // false' "$CONFIG_FILE")
        if [ "$matugen_enabled" = "true" ]; then
            wallpaper=$(jq -r '.appearance.background.wallpaperPath // ""' "$CONFIG_FILE")
            wallpaper="${wallpaper#file://}"
            if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
                scheme=$(jq -r '.appearance.background.matugenScheme // "scheme-tonal-spot"' "$CONFIG_FILE")
                darkmode=$(jq -r '.appearance.background.darkmode // true' "$CONFIG_FILE")
                [ "$darkmode" = "true" ] && mode="dark" || mode="light"
                matugen -c ~/.config/matugen/config.toml -t "$scheme" -m "$mode" image "$wallpaper" --source-color-index 0
            fi
        else
            custom_color=$(jq -r '.appearance.background.matugenCustomColor // ""' "$CONFIG_FILE")
            if [ -n "$custom_color" ]; then
                scheme=$(jq -r '.appearance.background.matugenScheme // "scheme-tonal-spot"' "$CONFIG_FILE")
                darkmode=$(jq -r '.appearance.background.darkmode // true' "$CONFIG_FILE")
                [ "$darkmode" = "true" ] && mode="dark" || mode="light"
                matugen -c ~/.config/matugen/config.toml -t "$scheme" -m "$mode" color hex "$custom_color"
            fi
        fi
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac
