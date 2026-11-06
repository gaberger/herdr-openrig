# herdr-openrig

A ccs/Claude plugin that adds an OpenRig panel to the [Herdr](https://herdr.dev) app.
Press `cmd-shift-o` in Herdr to see every rig and its seats; click a seat to attach
to its tmux session, or "view" to place the rig's tiles in Herdr.

## Install with ccs

```bash
ccs library add gaberger/herdr-openrig
ccs kit new herdr
ccs kit use herdr plugins/herdr-openrig
ccs kit attach herdr <profile>
```

Start a new session with `ccs <profile>` and ask Claude to "install the herdr
openrig mod" (skill `install-herdr-openrig-mod`). Or run the installer yourself:

```bash
bash skills/install-herdr-openrig-mod/scripts/install.sh            # install / update
bash skills/install-herdr-openrig-mod/scripts/install.sh --remove   # uninstall
```

The installer copies the mod to `~/.config/herdr-app/mods/openrig/`, binds
`cmd-shift-o` only if that key is free (backing up `keys.json` first), and runs
`herdr-app check`. It refuses to overwrite a different mod named `openrig`
unless you pass `--force`.

## What the mod does

It runs programs: `rig` (found once via `zsh -ic 'command -v rig'`, then cached),
and `tmux attach` in a new Herdr tab when you click a seat. It reads nothing
outside its own folder.

## Requirements

Herdr app installed and run once, and the OpenRig CLI (`rig`).

## Update

`ccs library update plugins/herdr-openrig`
