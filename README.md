<div align="center">

<img src="assets/logo.svg" width="64" alt="Caelestia logo" />

# caelestia-kde — Termux

[![KDE Plasma](https://img.shields.io/badge/Plasma_6-1D99F3?logo=kde&logoColor=white&style=for-the-badge&labelColor=101418)](https://kde.org/plasma-desktop)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-9bd0cc?style=for-the-badge&labelColor=101418)](LICENSE)

</div>

> [!WARNING]
> **Termux-only, experimental, unstable.** This branch runs Caelestia KDE on Android via Termux (no root) + Anland. Expect glitches, visual artifacts, and a noisy log. Not a daily driver.

## What works / what doesn't

**Works:** shell launches, bar / drawers / dashboard, KWin workspace tracking (KDE bridge), audio (PipeWire + PulseAudio via Anland), GStreamer multimedia, window screencast (`zkde_screencast_unstable_v1`), crash-recovery shortcuts.

**Disabled on Termux (no root / no system services):** lock screen, KWin workspace-tracker effect, SDDM theme, polkit agent, audio visualiser (`libcava`/`aubio`), hardware sensors (`lm_sensors`), `kde-material-you-colors`.

**Noisy warnings — safe to ignore:**
- `darkly` decoration / plasma theme not found — falls back to Breeze
- `kameleon` kded module missing — cosmetic
- `Fontconfig: /etc/fonts/fonts.conf` not found — Termux keeps it at `$PREFIX/etc/fonts/fonts.conf`, overridden via `FONTCONFIG_FILE`
- `QSettings organizationName` — Quickshell `Settings` type limitation
- `CavaProvider is not a type` — visualiser disabled
- `inotify_add_watch Permission denied` — Android SELinux
- `load glyph failed err=6` — 2 Material Symbols codepoints, cosmetic
- `/proc/uptime`, `/proc/sys/kernel/*`, `/etc/os-release` — restricted on Android, handled gracefully
- `xdg-desktop-portal` / `org.freedesktop.portal.Error.Failed` — Android portal restrictions

## Prerequisites

1. [Termux](https://f-droid.org/packages/com.termux/) from F-Droid (not Play Store).
2. Enable the X11 repo:

```bash
pkg install x11-repo
pkg update
```

3. Install KDE Plasma + Anland compositor via [lfdevs/anland-termux](https://github.com/lfdevs/anland-termux):

```bash
# Follow anland-termux's own install instructions.
# It provides: kwin_wayland, plasmashell, startplasma-anland.sh, PipeWire, etc.
```

Verify:

```bash
ls ~/startplasma-anland.sh
```

## Installation (Termux only)

```bash
pkg install git
git clone https://github.com/enderbk0/caelestia-kde-termux
cd caelestia-kde-termux
bash install-termux.sh
```

`install-termux.sh` is the **only** installer for Termux. Do not use `install.sh` / `scripts/` — those target desktop Linux.

What it does (all inside `$PREFIX` / `$HOME`, no root):
- installs Termux packages: `qt6-*`, `kf6-*`, `quickshell`, `pipewire`, `pulseaudio`, `ttf-jetbrains-mono`, `ttf-nerd-fonts-symbols`, downloads Material Symbols Rounded + Rubik, runs `fc-cache`
- builds the C++ QML plugin (`shell/plugin`) with `-DANDROID=OFF -DCMAKE_SYSTEM_NAME=Linux` — `aubio`/`libcava`/`lm_sensors`/`KGlobalAccel` are optional with stubs
- installs QML modules to `~/.local/lib/qt6/qml` and shell config to `~/.config/quickshell/caelestia`
- deploys the monochrome icon set, creates default `~/.local/state/caelestia/scheme.json`
- writes `~/.local/bin/caelestia-autostart.sh` + KDE autostart entry `~/.config/autostart/caelestiashell.desktop` (inherits `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` / PipeWire env from `startplasma-anland.sh`)

Flags:

```bash
bash install-termux.sh --force-build   # force rebuild
bash install-termux.sh --skip-config   # skip KDE config deployment
```

Logs: `$TMPDIR/caelestia-*.log` (cmake/build/install), plus `$TMPDIR/run/quickshell/by-id/*/log.qslog`.

## Running

```bash
~/startplasma-anland.sh
# "Starting KDE Plasma. Please switch to the Anland Termux app." → switch to the Anland viewer app
```

The shell autostarts via `caelestiashell.desktop` → `caelestia-autostart.sh` → `quickshell`. Do not override `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` / `PIPEWIRE_RUNTIME_DIR` — they are set by `startplasma-anland.sh`.

Manual launch (inside an Anland session only):

```bash
~/.local/bin/caelestia-shell
```

View logs:

```bash
cat "$TMPDIR/run/quickshell/by-id/"*/log.qslog | tail -n 100
```

## Updating / Uninstalling

Updating: re-run `bash install-termux.sh` (or `bash install-termux.sh --force-build`). Shell settings at `~/.config/caelestia/shell.json` are preserved.

Uninstall:

```bash
rm ~/.config/autostart/caelestiashell.desktop
rm -rf ~/.config/quickshell/caelestia ~/.local/state/caelestia
# optionally: rm ~/.local/bin/caelestia-autostart.sh ~/.local/bin/caelestia-shell
```

## Keybinds

| Shortcut | Action |
| --- | --- |
| `Super` | App launcher |
| `Super + /` | Keybind cheatsheet |
| `Super + Enter` | Terminal |
| `Super + Tab` | Overview |
| `Super + 1-5` | Switch workspace |
| `Super + B` | Notification sidebar |
| `Super + V` | Clipboard history |
| `Super + Shift + S` | Screenshot |
| `Super + Shift + A` | Google Lens |
| `Super + Shift + D` | Text recognition |
| `Super + Ctrl + S` | Screen recorder |
| `Super + Shift + C` | Color picker |
| `Super + Shift + V` | Emoji selector |

## Configuring

Open Nexus (`Super`, then `>Settings`).

- Appearance: wallpaper, colors, fonts, slideshow
- Panels: bar, dashboard, launcher, sidebar, overview
- Desktop: window rules, context menu, Krohnkite
- Shortcuts: rebind or add command shortcuts
- Plugins: browse the store or install your own

Set wallpaper from Appearance. The stock KDE wallpaper manager leaves the shell on stale colors.

Settings are written to `~/.config/caelestia/shell.json`.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Widgets not appearing | Log out and back in, or run `~/.local/bin/caelestia-shell` inside the Anland session |
| Colors not applying | Re-run `bash install-termux.sh`; verify `~/.local/state/caelestia/scheme.json` exists |
| Install failed mid-way | Check `$TMPDIR/caelestia-*.log`, then re-run `bash install-termux.sh --force-build` |
| Shell won't start (`WAYLAND_DISPLAY` missing) | Start via `~/startplasma-anland.sh` first; don't launch outside Anland |
| Icons show as boxes | `fc-cache -f` and verify `fc-match "Material Symbols Rounded"` returns the font |

Check quickshell logs at `$TMPDIR/run/quickshell/by-id/*/log.qslog`. Enable Debug Mode in Nexus → About → Advanced, then reproduce.

No issue tracker — this is an experimental port.

## Repository layout

```
install-termux.sh  Termux/Android installer (no root, $PREFIX only)
shell/             QML shell and C++ QML plugin (Termux-patched for optional deps)
src/               files copied onto the system, plus vendored submodules
assets/            logo used by the docs
docs/              guides, plus design notes under docs/architecture/
```

Desktop install pipeline (`install.sh`, `installer/`, `scripts/`) is not used on Termux.

## Credits

- [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (GPL-3.0-or-later) and the [Caelestia dotfiles](https://github.com/caelestia-dots/caelestia) (GPL-3.0-or-later) by [@soramanew](https://github.com/soramanew) — original design language, shell and dotfiles this port is built on
- [ladybug-me/caelestia-kde](https://github.com/ladybug-me/caelestia-kde) (GPL-3.0-or-later) — KDE Plasma port of the Caelestia shell; Termux branch is derived from this port
- [0xSolanaceae](https://github.com/0xSolanaceae) — head maintainer of the KDE port
- [Bali10050/Darkly](https://github.com/Bali10050/Darkly) (GPL-2.0-or-later) — Darkly Qt style / KWin decoration
- [wrymt/darkly-gtk](https://github.com/wrymt/darkly-gtk) (GPL-3.0-or-later) — Darkly GTK theme
- [Haidir / yet-another-monochrome-icon-set](https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set) (GPL-3.0-or-later) — monochrome icon set (`src/yet-another-monochrome-icon-set`, deployed to `~/.config/quickshell/caelestia/assets/icons/`)
- [lfdevs/anland-termux](https://github.com/lfdevs/anland-termux) — Anland Wayland compositor and Termux KDE Plasma session (`startplasma-anland.sh`, PipeWire setup, `XDG_RUNTIME_DIR` handling)
- [Quickshell](https://quickshell.org) (GPL-3.0-or-later) — QML shell toolkit
- [Termux](https://termux.dev) — Android terminal and `$PREFIX` environment
- [enderbk0/caelestia-kde-termux](https://github.com/enderbk0/caelestia-kde-termux) — Termux-specific patches and `install-termux.sh` (optional deps, stubs, Termux paths)

If you redistribute this Termux port, preserve the copyright notices above and comply with each component's license.

## License

This Termux port is licensed under **GPL-3.0-or-later**, same as upstream — see [LICENSE](LICENSE).

- `LICENSE` covers this port and the KDE port it derives from.
- Vendored / deployed third-party assets keep their own licenses:
  - `src/yet-another-monochrome-icon-set` — GPL-3.0-or-later
  - Darkly (`Bali10050/Darkly`, `wrymt/darkly-gtk`) — GPL-2.0-or-later / GPL-3.0-or-later respectively
  - Upstream shell assets from `caelestia-dots/shell` — GPL-3.0-or-later
