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

        # Read settings from preset_file first to run matugen BEFORE updating config.json
        # This prevents Quickshell from reloading active.json with outdated/fallback colors first
        merged_json=$(jq -s '.[0] * .[1] | del(._presetMeta)' "$CONFIG_FILE" "$preset_file")

        matugen_enabled=$(echo "$merged_json" | jq -r '.appearance.background.matugen // false')
        custom_color=$(echo "$merged_json" | jq -r '.appearance.background.matugenCustomColor // .appearance.palette.accentColor // .palette.accentColor // ""')
        theme_file=$(echo "$merged_json" | jq -r '.appearance.background.matugenThemeFile // ""')

        scheme=$(echo "$merged_json" | jq -r '.appearance.background.matugenScheme // "scheme-tonal-spot"')
        darkmode=$(echo "$merged_json" | jq -r '.appearance.background.darkmode // true')
        [ "$darkmode" = "true" ] && mode="dark" || mode="light"

        if [ "$matugen_enabled" = "false" ] && [ -n "$custom_color" ] && [ "$custom_color" != "null" ] && [ "$custom_color" != '""' ]; then
            custom_color_clean="${custom_color#\#}"
            # Ensure both matugenCustomColor and palette.accentColor in merged_json have the '#' prefix
            merged_json=$(echo "$merged_json" | jq --arg c "#$custom_color_clean" '.appearance.background.matugenCustomColor = $c | .appearance.palette.accentColor = $c')
            
            # Generate theme files via Matugen first
            matugen -c ~/.config/matugen/config.toml -t "scheme-tonal-spot" -m "$mode" color hex "$custom_color_clean"
            
            # Write config.json after matugen finishes
            echo "$merged_json" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            touch "$HOME/.config/nandoroid/colors/active.json"
        elif [ "$matugen_enabled" = "false" ] && [ -n "$theme_file" ] && [ "$theme_file" != "null" ] && [ -f "$HOME/.config/nandoroid/colors/$theme_file" ]; then
            cp "$HOME/.config/nandoroid/colors/$theme_file" "$HOME/.config/nandoroid/colors/active.json"
            echo "$merged_json" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            touch "$HOME/.config/nandoroid/colors/active.json"
        else
            wallpaper=$(echo "$merged_json" | jq -r '.appearance.background.wallpaperPath // ""')
            wallpaper="${wallpaper#file://}"
            if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
                matugen -c ~/.config/matugen/config.toml -t "$scheme" -m "$mode" image "$wallpaper" --source-color-index 0
            fi
            echo "$merged_json" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        fi
        ;;
    *)
        echo "Error: unknown action: $action" >&2
        exit 1
        ;;
esac
