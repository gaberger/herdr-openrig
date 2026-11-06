---
name: install-herdr-openrig-mod
description: Use when the user wants the OpenRig panel in the Herdr app (herdr-app), asks to install, update or remove the herdr openrig mod, or wants rigs and seats listed inside Herdr with cmd-shift-o.
---

# Install the OpenRig panel into Herdr

Herdr (`herdr-app`) is extended by mods in `~/.config/herdr-app/mods/<name>/`.
This skill carries the `openrig` mod and an installer. The mod is a popup that
lists rigs and seats from `rig ps --json`. Clicking a seat opens a tab running
`tmux attach` for it; "view" runs `rig terminal open <rig> --provider herdr`.

**Tell the user before installing:** the mod runs programs (`rig`, via
`/usr/bin/env`, and `zsh -ic 'command -v rig'` once to locate it) and reads
nothing outside its own folder. The installer also adds one key to
`~/.config/herdr-app/keys.json`.

## Steps

1. Run the installer, from this skill's folder:
   ```bash
   bash scripts/install.sh            # install or update
   bash scripts/install.sh --remove   # uninstall
   ```
   It never overwrites a different mod already named `openrig` without
   `--force`, adds `cmd-shift-o` only if that key is unused, and backs up
   `keys.json` first.
2. It runs `herdr-app check` on the mod and reports the result. Do not call it
   done unless the check passed.
3. Open the panel with `herdr-app do mod.open --name openrig` (again closes it).
   Tell the user the key is cmd-shift-o.

## Requirements

- Herdr app installed (`herdr-app` on PATH, `~/.config/herdr-app` exists).
- `rig` (OpenRig CLI) installed; the mod finds it through an interactive zsh.

## Optional: agent status in Herdr

For Claude seats to show working/blocked/done in Herdr, the user can run
`herdr integration install claude`. That writes a hook into the Claude profile
config, so only do it when asked.
