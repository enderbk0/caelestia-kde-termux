#!/usr/bin/env bash
#
# Caelestia KDE — Termux Installer
#
# This script installs Caelestia KDE on Termux (Android, no root).
# It builds the C++ plugin, installs QML modules, deploys configs,
# applies KDE tweaks, and sets up autostart.
#
# Usage:
#   bash install-termux.sh [--force-build] [--skip-config]
#
# Prerequisites:
#   - Termux with x11-repo enabled (pkg install x11-repo)
#   - A Wayland compositor running (e.g. Termux:X11, wlroots-based)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
FORCE_BUILD="${1:-}"
SKIP_CONFIG="${2:-}"

# Termux: use $TMPDIR (not /tmp which may not be writable)
LOG_DIR="${TMPDIR:-$HOME/.cache/caelestia-kde}"
mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }

# ── Step 1: Check environment ──────────────────────────────────────────

info "Checking Termux environment..."

if [[ ! -d "$PREFIX" ]]; then
    die "PREFIX directory not found: $PREFIX"
fi

# ── Step 2: Install required packages ──────────────────────────────────

info "Installing required Termux packages..."

PACKAGES=(
    # Core build tools
    cmake pkg-config ccache

    # Qt6
    qt6-qtbase qt6-qtdeclarative qt6-qtwayland qt6-qtsvg
    qt6-qttools qt6-qt5compat qt6-qtmultimedia qt6-qtshadertools

    # KF6
    kf6-kconfig kf6-kwindowsystem kf6-kglobalaccel kf6-kguiaddons
    kf6-kpackage kf6-kirigami kf6-knotifications kf6-ksvg
    kf6-kcolorscheme kf6-kcodecs kf6-kcoreaddons kf6-ki18n
    kf6-kiconthemes kf6-kitemmodels kf6-kwidgetsaddons kf6-kdbusaddons
    kf6-solid kf6-sonnet kf6-prison kf6-kcmutils

    # Wayland (libwayland/protocols are already base packages in Termux)
    libwayland-protocols plasma-wayland-protocols

    # Quickshell
    quickshell

    # Audio
    pipewire pulseaudio

    # Fonts
    ttf-jetbrains-mono ttf-nerd-fonts-symbols

    # X11 (for XCB support)
    libx11 libxcb

    # Other
    extra-cmake-modules
)

# Packages that exist under different names or are already installed
# - wayland: doesn't exist as standalone package, libwayland is a base dep
# - layer-shell-qt: may be held, skip if held
# - libqalculate: package is qalculate-gtk (already installed)
# - pulseaudio-qt: may be held, check separately

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        continue
    fi
    # Skip held packages entirely — they're already configured for this setup
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^h"; then
        info "Skipping held package: $pkg"
        continue
    fi
    info "Installing $pkg..."
    pkg install -y "$pkg" 2>/dev/null || \
        warn "Failed to install $pkg (may not be critical)"
done

# These may be held — just verify they exist, don't touch them
for pkg in layer-shell-qt pulseaudio-qt ninja; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ih\|^ii"; then
        continue
    fi
    warn "$pkg not installed and not held — you may need to install it manually"
done

ok "Package check complete."

# ── Step 3: Initialize submodules ───────────────────────────────────────

info "Initializing git submodules..."

if [[ -f "$SCRIPT_DIR/.gitmodules" ]]; then
    git -C "$SCRIPT_DIR" submodule sync --recursive 2>/dev/null || true
    git -C "$SCRIPT_DIR" submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" 2>/dev/null || \
        warn "Submodule init failed (non-fatal if already initialized)"
fi

ok "Submodules ready."

# ── Step 4: Build the shell ────────────────────────────────────────────

BUILD_DIR="$SCRIPT_DIR/shell/build"
INSTALL_PREFIX="$HOME/.local"
SHELL_CONFIG_DIR="$HOME/.config/quickshell/caelestia"
QML_DIR="$INSTALL_PREFIX/lib/qt6/qml"
LIB_DIR="$INSTALL_PREFIX/lib/caelestia"

info "Building Caelestia shell for Termux..."

# Detect available features
DETECTED_FEATURES=""

if pkg-config --exists libpipewire-0.3 2>/dev/null; then
    DETECTED_FEATURES="$DETECTED_FEATURES PipeWire"
fi

if pkg-config --exists libqalculate 2>/dev/null; then
    DETECTED_FEATURES="$DETECTED_FEATURES Qalculate"
fi

if pkg-config --exists aubio 2>/dev/null; then
    DETECTED_FEATURES="$DETECTED_FEATURES Aubio"
fi

if [[ -f "$PREFIX/include/sensors/sensors.h" ]]; then
    DETECTED_FEATURES="$DETECTED_FEATURES Sensors"
fi

if [[ -f "$PREFIX/lib/cmake/KF6GlobalAccel/KF6GlobalAccelConfig.cmake" ]]; then
    DETECTED_FEATURES="$DETECTED_FEATURES KGlobalAccel"
fi

info "Detected features:$DETECTED_FEATURES"

# Use ninja if available
CMAKE_GENERATOR="Unix Makefiles"
if command -v ninja >/dev/null 2>&1; then
    CMAKE_GENERATOR="Ninja"
fi

# Prepare build directory — always clean stale cache to avoid generator conflicts
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    # Check if the cached generator matches what we want
    cached_gen=$(grep CMAKE_MAKE_PROGRAM "$BUILD_DIR/CMakeCache.txt" 2>/dev/null || echo "")
    if [[ "$FORCE_BUILD" == "--force-build" ]] || [[ -n "$cached_gen" ]]; then
        info "Cleaning stale CMake cache..."
        rm -rf "$BUILD_DIR"
    fi
fi
mkdir -p "$BUILD_DIR"

info "Configuring CMake..."
cmake -G "$CMAKE_GENERATOR" \
    -B "$BUILD_DIR" \
    -S "$SCRIPT_DIR/shell" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DINSTALL_LIBDIR="lib/caelestia" \
    -DINSTALL_QMLDIR="lib/qt6/qml" \
    -DINSTALL_QSCONFDIR="$SHELL_CONFIG_DIR" \
    -DENABLE_MODULES="extras;plugin;shell;m3shapes" \
    -DCAELESTIA_CACHE_DEPS=ON \
    -DANDROID=OFF \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DQT_NO_PRIVATE_MODULE_WARNING=ON \
    2>&1 | tee "$LOG_DIR/caelestia-cmake.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    die "CMake configuration failed. Check $LOG_DIR/caelestia-cmake.log"
fi

ok "CMake configured."

# Build
BUILD_JOBS="${CAELESTIA_BUILD_JOBS:-$(( $(nproc 2>/dev/null || echo 2) - 1 ))}"
[[ $BUILD_JOBS -lt 1 ]] && BUILD_JOBS=1

info "Building with $BUILD_JOBS parallel jobs..."
cmake --build "$BUILD_DIR" -j"$BUILD_JOBS" 2>&1 | tee "$LOG_DIR/caelestia-build.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    die "Build failed. Check $LOG_DIR/caelestia-build.log"
fi

ok "Build complete."

# ── Step 5: Install ────────────────────────────────────────────────────

info "Installing to $INSTALL_PREFIX..."

cmake --install "$BUILD_DIR" 2>&1 | tee "$LOG_DIR/caelestia-install.log"

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    die "Installation failed. Check $LOG_DIR/caelestia-install.log"
fi

ok "Installed to $INSTALL_PREFIX"

# ── Step 6: Install shell QML source ───────────────────────────────────

info "Installing shell QML source to $SHELL_CONFIG_DIR..."

mkdir -p "$SHELL_CONFIG_DIR"

# Copy shell directories
for dir in assets components modules scripts services utils; do
    if [[ -d "$SCRIPT_DIR/shell/$dir" ]]; then
        rsync -a --delete "$SCRIPT_DIR/shell/$dir/" "$SHELL_CONFIG_DIR/$dir/" 2>/dev/null || \
            cp -r "$SCRIPT_DIR/shell/$dir" "$SHELL_CONFIG_DIR/"
    fi
done

# Install shell.qml (with watchFiles disabled for production)
sed 's/settings\.watchFiles: true/settings.watchFiles: false/' \
    "$SCRIPT_DIR/shell/shell.qml" > "$SHELL_CONFIG_DIR/shell.qml"

# Install lockscreen.qml
cp "$SCRIPT_DIR/shell/lockscreen.qml" "$SHELL_CONFIG_DIR/" 2>/dev/null || true

# Install translations
if [[ -d "$SCRIPT_DIR/shell/translations" ]]; then
    mkdir -p "$SHELL_CONFIG_DIR/translations"
    cp "$SCRIPT_DIR/shell/translations/"*.qm "$SHELL_CONFIG_DIR/translations/" 2>/dev/null || true
fi

ok "Shell QML installed."

# ── Step 7: Deploy CLI scripts and bridge scripts ──────────────────────

info "Installing CLI wrappers and bridge scripts..."

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/kwin/scripts"

# Deploy ALL scripts from src/bin/
for script in "$SCRIPT_DIR"/src/bin/*; do
    [[ -f "$script" ]] || continue
    [[ "$(basename "$script")" == *.cpp || "$(basename "$script")" == CMakeLists.txt ]] && continue
    install -m 755 "$script" "$HOME/.local/bin/$(basename "$script")"
done

ok "CLI wrappers installed to ~/.local/bin/"

# ── Step 8: Copy icon set ──────────────────────────────────────────────

info "Installing icon set..."

ICON_DIR="$SHELL_CONFIG_DIR/assets/icons/yet-another-monochrome-icon-set"
if [[ -d "$SCRIPT_DIR/src/yet-another-monochrome-icon-set" ]]; then
    mkdir -p "$(dirname "$ICON_DIR")"
    rsync -a --delete --exclude='.git' "$SCRIPT_DIR/src/yet-another-monochrome-icon-set/" "$ICON_DIR/" 2>/dev/null || \
        cp -r "$SCRIPT_DIR/src/yet-another-monochrome-icon-set" "$ICON_DIR"
fi

ok "Icon set installed."

# ── Step 8b: Install fonts ───────────────────────────────────────────

info "Installing fonts..."

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Download Material Symbols Rounded (icon font) if not present
if ! fc-match "Material Symbols Rounded" 2>/dev/null | grep -qi "Material Symbols"; then
    info "Downloading Material Symbols Rounded..."
    curl -sL -o "$FONT_DIR/MaterialSymbolsRounded.ttf" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" || \
        warn "Failed to download Material Symbols Rounded"
fi

# Download Rubik font (clock/workspace) if not present
if ! fc-match "Rubik" 2>/dev/null | grep -qi "Rubik"; then
    info "Downloading Rubik font..."
    curl -sL -o "$FONT_DIR/Rubik%5Bwght%5D.ttf" \
        "https://github.com/google/fonts/raw/refs/heads/main/ofl/rubik/Rubik%5Bwght%5D.ttf" || \
        warn "Failed to download Rubik font"
fi

fc-cache -f 2>/dev/null || true
ok "Fonts installed."

# ── Step 8c: Create default colour scheme ──────────────────────────────

info "Creating default colour scheme..."

STATE_DIR="$HOME/.local/state/caelestia"
mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_DIR/scheme.json" ]]; then
    cat > "$STATE_DIR/scheme.json" << 'SCHEME'
{
  "name": "dynamic",
  "flavour": "default",
  "variant": "default",
  "mode": "dark",
  "colours": {
    "primary": "FFB0CA", "onPrimary": "3D2F36", "primaryContainer": "55454D", "onPrimaryContainer": "FFD8E2",
    "secondary": "E3BDC8", "onSecondary": "3E2E35", "secondaryContainer": "56444C", "onSecondaryContainer": "FFD8E2",
    "tertiary": "E3BDC8", "onTertiary": "3E2E35", "tertiaryContainer": "56444C", "onTertiaryContainer": "FFD8E2",
    "error": "FFB4AB", "onError": "690005", "errorContainer": "93000A", "onErrorContainer": "FFDAD6",
    "success": "A8DAB5", "onSuccess": "1B3724", "successContainer": "324E3A", "onSuccessContainer": "C4F6CF",
    "background": "1A1118", "onBackground": "ECDFE5",
    "surface": "1A1118", "surfaceDim": "1A1118", "surfaceBright": "413740",
    "surfaceContainerLowest": "140C12", "surfaceContainerLow": "231920", "surfaceContainer": "271D24",
    "surfaceContainerHigh": "32282F", "surfaceContainerHighest": "3D333A",
    "onSurface": "ECDFE5", "surfaceVariant": "524349", "onSurfaceVariant": "D6C2C9",
    "inverseSurface": "ECDFE5", "inverseOnSurface": "362F34",
    "outline": "9E8C93", "outlineVariant": "D6C2C9", "shadow": "000000", "scrim": "000000",
    "surfaceTint": "FFB0CA", "inversePrimary": "6E5660",
    "primaryFixed": "FFD8E2", "primaryFixedDim": "E8BAC5", "onPrimaryFixed": "24171E", "onPrimaryFixedVariant": "3D2F36",
    "secondaryFixed": "FFD8E2", "secondaryFixedDim": "E3BDC8", "onSecondaryFixed": "24171E", "onSecondaryFixedVariant": "3E2E35",
    "tertiaryFixed": "FFD8E2", "tertiaryFixedDim": "E3BDC8", "onTertiaryFixed": "24171E", "onTertiaryFixedVariant": "3E2E35",
    "primary_paletteKeyColor": "FFB0CA", "secondary_paletteKeyColor": "E3BDC8", "tertiary_paletteKeyColor": "E3BDC8",
    "neutral_paletteKeyColor": "ECDFE5", "neutral_variant_paletteKeyColor": "D6C2C9",
    "term0": "1A1118", "term1": "FFB0CA", "term2": "A8DAB5", "term3": "E3BDC8",
    "term4": "B5A0D9", "term5": "FFB0CA", "term6": "A8DAB5", "term7": "ECDFE5",
    "term8": "3D333A", "term9": "FFB0CA", "term10": "A8DAB5", "term11": "E3BDC8",
    "term12": "B5A0D9", "term13": "FFB0CA", "term14": "A8DAB5", "term15": "ECDFE5"
  }
}
SCHEME
    ok "Default scheme.json created."
else
    ok "scheme.json already exists."
fi

# ── Step 9: Set up environment variables ───────────────────────────────

info "Setting up environment..."

BASHRC="$HOME/.bashrc"
QML_PATH_ENTRY="export QML2_IMPORT_PATH=\"$QML_DIR:$SHELL_CONFIG_DIR\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}\""
LIB_PATH_ENTRY="export CAELESTIA_LIB_DIR=\"$LIB_DIR\""

if ! grep -q "caelestia" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# Caelestia KDE" >> "$BASHRC"
    echo "$QML_PATH_ENTRY" >> "$BASHRC"
    echo "$LIB_PATH_ENTRY" >> "$BASHRC"
    info "Added environment variables to ~/.bashrc"
fi

export QML2_IMPORT_PATH="$QML_DIR:$SHELL_CONFIG_DIR${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export CAELESTIA_LIB_DIR="$LIB_DIR"

# ── Step 10: Validate QML modules ─────────────────────────────────────

info "Validating QML modules..."

QML_MODULES=(
    Caelestia Caelestia/Components Caelestia/Config Caelestia/Settings
    Caelestia/Models Caelestia/Services Caelestia/Blobs Caelestia/Images
    Caelestia/Layouts M3Shapes
)

VALIDATION_FAILED=0
for module in "${QML_MODULES[@]}"; do
    module_dir="$QML_DIR/$module"
    if [[ ! -f "$module_dir/qmldir" ]]; then
        err "Missing QML module: $module_dir/qmldir"
        VALIDATION_FAILED=1
    fi
done

if [[ $VALIDATION_FAILED -eq 1 ]]; then
    die "QML module validation failed."
fi

ok "All QML modules validated."

# ══════════════════════════════════════════════════════════════════════
# KDE CONFIGURATION (replicating steps 04, 09, 10 from original pipeline)
# ══════════════════════════════════════════════════════════════════════

if [[ "$SKIP_CONFIG" == "--skip-config" ]]; then
    warn "Skipping KDE configuration (--skip-config)."
else

# ── Step 11: Deploy KDE configs (from 04-deploy-kde.sh) ────────────────

info "Configuring KDE theme and settings..."

# Darkly theme
kwriteconfig6 --file plasmarc --group "Theme" --key "name" "darkly" 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group "KDE" --key "widgetStyle" "darkly" 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme" "Darkly" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.darkly" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "theme" "@darkly" 2>/dev/null || true

# Apply look and feel (may not be available on Termux)
command -v lookandfeeltool >/dev/null 2>&1 && \
    lookandfeeltool --apply "Darkly" 2>/dev/null || true

ok "KDE theme configured."

# ── Step 12: System tweaks (from 09-system-tweaks.sh) ──────────────────

info "Applying system tweaks..."

# 5 virtual desktops
kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "5" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows" "1" 2>/dev/null || true
for i in 1 2 3 4 5; do
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i" 2>/dev/null || true
done

# Disable KDE OSD (conflicts with Caelestia's OSD)
kwriteconfig6 --file plasmarc --group "OSD" --key "Enabled" "false" 2>/dev/null || true
kwriteconfig6 --file plasmarc --group "OSD" --key "ShowOnActiveScreen" "false" 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group "KDE" --key "OSDEnabled" "false" 2>/dev/null || true
kwriteconfig6 --file plasmanotifyrc --group "Notifications" --key "LoudnessChangedOSD" "false" 2>/dev/null || true
kwriteconfig6 --file powerdevilrc --group "BrightnessControl" --key "showOSD" "false" 2>/dev/null || true
kwriteconfig6 --file powerdevilrc --group "AC" --key "brightnessosd" "false" 2>/dev/null || true

# Remove default KDE panels (Caelestia shell replaces them)
# This is done via qdbus when a Plasma session is running
if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
        "var p = panels(); for (var i = 0; i < p.length; i++) { p[i].remove(); }" \
        2>/dev/null || true
fi

ok "System tweaks applied."

# ── Step 13: Wallpaper setup ───────────────────────────────────────────

info "Setting up wallpaper..."

WALLPAPER_DIR="$HOME/.local/state/caelestia/wallpaper"
mkdir -p "$WALLPAPER_DIR"

# Use default wallpaper if available
DEFAULT_WALLPAPER="$SCRIPT_DIR/shell/assets/wallpapers/default.jpg"
if [[ -f "$DEFAULT_WALLPAPER" ]]; then
    cp "$DEFAULT_WALLPAPER" "$WALLPAPER_DIR/default.jpg"
    echo "file://$WALLPAPER_DIR/default.jpg" > "$WALLPAPER_DIR/path.txt"

    # Set wallpaper via KDE (if session running)
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
            var allDesktops = desktops();
            for (var i=0; i<allDesktops.length; i++) {
                allDesktops[i].wallpaperPlugin = 'org.kde.image';
                allDesktops[i].currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
                allDesktops[i].writeConfig('Image', 'file://$WALLPAPER_DIR/default.jpg');
            }
        " 2>/dev/null || true
    fi
fi

ok "Wallpaper configured."

# ── Step 14: Autostart setup (from 10-autostart.sh) ────────────────────

info "Setting up autostart..."

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# Create the Caelestia Shell autostart entry
QUICKSHELL_PATH="$(command -v quickshell 2>/dev/null || echo "$PREFIX/bin/quickshell")"

cat > "$AUTOSTART_DIR/caelestiashell.desktop" << AUTOSTART
[Desktop Entry]
Comment=Caelestia KDE Shell
Exec=$HOME/.local/bin/caelestia-autostart.sh
Icon=caelestia
Name=Caelestia Shell
OnlyShowIn=KDE;
StartupNotify=false
Terminal=false
Type=Application
X-KDE-AutostartPhase=1
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1
X-DBUS-StartupType=Unique
X-DesktopAutostartCondition=KDE
AUTOSTART

# Create the autostart wrapper script
cat > "$HOME/.local/bin/caelestia-autostart.sh" << 'AUTOSTART_SH'
#!/usr/bin/env bash
# Caelestia Shell autostart wrapper for Termux
#
# IMPORTANT: This script runs inside the KDE Plasma session started by
# startplasma-anland.sh. It MUST inherit the parent environment (WAYLAND_DISPLAY,
# XDG_RUNTIME_DIR, PIPEWIRE_RUNTIME_DIR, etc.) — do NOT override them.
# PipeWire is already started by startplasma-anland.sh.

export QML2_IMPORT_PATH="${HOME}/.local/lib/qt6/qml:${HOME}/.config/quickshell/caelestia${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"
export CAELESTIA_LIB_DIR="${HOME}/.local/lib/caelestia"
export QS_NO_RELOAD_POPUP=1
export QS_DROP_EXPENSIVE_FONTS=1
export QSG_RENDER_LOOP=threaded
export QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
export FONTCONFIG_FILE="${PREFIX:-/data/data/com.termux/files/usr}/etc/fonts/fonts.conf"
export QT_ORG_NAME="caelestia"
export QT_DOMAIN="caelestia-kde"

# Wait for Wayland display to become available (KWin needs time to start)
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    for i in $(seq 1 50); do
        if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then break; fi
        sleep 0.2
    done
fi

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "ERROR: WAYLAND_DISPLAY not set after waiting." >&2
    exit 1
fi

exec quickshell -n -p "${HOME}/.config/quickshell/caelestia/shell.qml"
AUTOSTART_SH

chmod 755 "$HOME/.local/bin/caelestia-autostart.sh"

# Create Wayland screencast desktop entry (needed for notifications/live previews)
cat > "$HOME/.local/share/applications/quickshell.desktop" << SCREENCAST
[Desktop Entry]
Comment=Caelestia Shell (Wayland screencast)
Exec=$QUICKSHELL_PATH
Icon=quickshell
Name=Caelestia Shell (Screencast)
NoDisplay=true
Terminal=false
Type=Application
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1,org_kde_plasma_window_management
SCREENCAST

# Create the manual launcher script
cat > "$HOME/.local/bin/caelestia-shell" << LAUNCHER
#!/usr/bin/env bash
# Caelestia KDE Shell Launcher for Termux
# NOTE: Run this inside an Anland session (WAYLAND_DISPLAY must be set).

export QML2_IMPORT_PATH="${HOME}/.local/lib/qt6/qml:${HOME}/.config/quickshell/caelestia${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"
export CAELESTIA_LIB_DIR="${HOME}/.local/lib/caelestia"
export QS_NO_RELOAD_POPUP=1
export QS_DROP_EXPENSIVE_FONTS=1
export QSG_RENDER_LOOP=threaded
export QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
export FONTCONFIG_FILE="\${PREFIX:-/data/data/com.termux/files/usr}/etc/fonts/fonts.conf"
export QT_ORG_NAME="caelestia"
export QT_DOMAIN="caelestia-kde"

if [[ -z "\${WAYLAND_DISPLAY:-}" ]]; then
    echo "ERROR: WAYLAND_DISPLAY not set. Start an Anland session first." >&2
    exit 1
fi

SHELL_DIR="${HOME}/.config/quickshell/caelestia"
if [[ ! -f "\$SHELL_DIR/shell.qml" ]]; then
    echo "Error: shell.qml not found at \$SHELL_DIR" >&2
    exit 1
fi

exec quickshell -d "\$SHELL_DIR"
LAUNCHER

chmod 755 "$HOME/.local/bin/caelestia-shell"

# Update desktop database
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

ok "Autostart configured."

# ── Step 15: Clipboard history (without systemd) ───────────────────────

info "Setting up clipboard history..."

# Check if cliphist is available
if command -v cliphist >/dev/null 2>&1; then
    # On Termux without systemd, start cliphist in the background
    # The shell itself manages clipboard via Quickshell services
    ok "cliphist available — managed by shell at runtime."
else
    warn "cliphist not installed. Clipboard history will use Quickshell's built-in manager."
fi

# ── Step 16: Reload KDE (if session running) ───────────────────────────

info "Reloading KDE configuration..."

if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    ok "KWin reconfigured."
else
    warn "qdbus6 not available — KDE config changes will take effect on next login."
fi

fi # end skip-config

# ══════════════════════════════════════════════════════════════════════

# ── Done ───────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Caelestia KDE for Termux — Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Installed to:     $INSTALL_PREFIX"
echo "  Shell config:     $SHELL_CONFIG_DIR"
echo "  QML modules:      $QML_DIR"
echo "  CLI wrappers:     $HOME/.local/bin/"
echo "  Autostart:        $HOME/.config/autostart/"
echo ""
echo "  Features detected:$DETECTED_FEATURES"
echo ""
echo "  To start the shell:"
echo "    1. Start a Wayland compositor (e.g., Termux:X11)"
echo "    2. Run: caelestia-shell"
echo "    Or it will auto-start on KDE login."
echo ""
echo "  Note: Some features are unavailable on Termux:"
echo "    - Lock screen (no kscreenlocker_greet)"
echo "    - KWin workspace tracker effect (no root access)"
echo "    - systemd services (no systemctl)"
echo "    - SDDM login theme (no SDDM)"
echo "    - Polkit authentication agent (no polkit)"
echo "    - Audio visualizer (cava not available)"
echo "    - Hardware sensors (lm_sensors not available)"
echo "    - kde-material-you-colors (no systemd service)"
echo ""
echo "  Run 'source ~/.bashrc' or open a new terminal to load paths."
echo ""
