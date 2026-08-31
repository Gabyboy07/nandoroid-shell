#!/bin/bash
set -e

echo "── matugen (via cargo) ──"
if ! command -v cargo >/dev/null 2>&1; then
    sudo dnf install -y cargo
fi
if ! command -v matugen >/dev/null 2>&1; then
    cargo install matugen
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
fi

echo "── quickshell ──"
if ! command -v quickshell >/dev/null 2>&1; then
    echo "quickshell n'a pas d'équivalent dnf/COPR fiable pour l'instant."
    echo "Build depuis source : https://github.com/quickshell-mirror/quickshell"
fi

echo "── songrec (flatpak) ──"
flatpak install -y --user flathub re.fossplant.songrec

echo "── Material Symbols ──"
FONT_DIR="$HOME/.local/share/fonts/material-symbols"
mkdir -p "$FONT_DIR"
git clone --depth 1 https://github.com/google/material-design-icons.git /tmp/material-icons
cp /tmp/material-icons/variablefont/*.ttf "$FONT_DIR"/ 2>/dev/null || true
rm -rf /tmp/material-icons

echo "── JetBrains Mono Nerd Font ──"
FONT_DIR2="$HOME/.local/share/fonts/jetbrains-mono-nerd"
mkdir -p "$FONT_DIR2"
wget -O /tmp/jbmono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o /tmp/jbmono.zip -d "$FONT_DIR2"
rm /tmp/jbmono.zip

fc-cache -fv

echo "Terminé. Vérifie matugen, quickshell (manuel), songrec, et les fonts."
