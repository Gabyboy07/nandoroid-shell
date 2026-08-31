#!/bin/bash
# Nandoroid Centralized Dependency Installer (Fedora)
# Usage: ./install_deps.sh <category>
CATEGORY=$1
DEP_JSON="data/dependencies.json"

if [ ! -f "$DEP_JSON" ]; then
    echo "Error: $DEP_JSON not found!"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    sudo dnf install -y jq
fi

# Table de correspondance Arch -> Fedora (paquets renommés)
declare -A PKG_MAP=(
    ["qt6-declarative"]="qt6-qtdeclarative"
    ["qt6-svg"]="qt6-qtsvg"
    ["qt6-wayland"]="qt6-qtwayland"
    ["imagemagick"]="ImageMagick"
    ["noto-fonts-emoji"]="google-noto-emoji-fonts"
    ["noto-fonts-cjk"]="google-noto-sans-cjk-fonts"
    ["adw-gtk-theme"]="adw-gtk3-theme"
    ["breeze"]="breeze-icon-theme"
    ["breeze-icons"]="kf6-breeze-icons"
    ["networkmanager"]="NetworkManager"
)

# Paquets sans équivalent dnf direct - installés à part
declare -A SKIP_PKGS=(
    ["quickshell-git"]=1
    ["matugen-bin"]=1
    ["songrec"]=1
    ["ttf-material-symbols-variable-git"]=1
    ["ttf-jetbrains-mono-nerd"]=1
    ["linux-wallpaperengine-git"]=1
    ["warp-cli"]=1
)

RAW_PACKAGES=$(jq -r ".$CATEGORY[].name" "$DEP_JSON")
if [ -z "$RAW_PACKAGES" ] || [ "$RAW_PACKAGES" == "null" ]; then
    echo "No packages found for category: $CATEGORY"
    exit 0
fi

FINAL_PACKAGES=()
for pkg in $RAW_PACKAGES; do
    if [[ -n "${SKIP_PKGS[$pkg]}" ]]; then
        echo "⚠ Skipping $pkg (no Fedora package - install manually, see README)"
        continue
    fi
    if [[ -n "${PKG_MAP[$pkg]}" ]]; then
        FINAL_PACKAGES+=("${PKG_MAP[$pkg]}")
    else
        FINAL_PACKAGES+=("$pkg")
    fi
done

if [ ${#FINAL_PACKAGES[@]} -eq 0 ]; then
    echo "Nothing to install for category: $CATEGORY"
    exit 0
fi

echo "Installing $CATEGORY dependencies..."
sudo dnf install -y "${FINAL_PACKAGES[@]}"
