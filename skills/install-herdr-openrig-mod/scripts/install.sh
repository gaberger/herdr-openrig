#!/usr/bin/env bash
# Install, update or remove the OpenRig mod for the Herdr app.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/mod/openrig"
HOME_DIR="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
DEST="$HOME_DIR/mods/openrig"
KEYS="$HOME_DIR/keys.json"
KEY="cmd-shift-o"
CMD="mod.open:openrig"
mode=install force=0
for a in "$@"; do
  case "$a" in --remove) mode=remove ;; --force) force=1 ;; *) echo "unknown arg: $a" >&2; exit 2 ;; esac
done

[ -d "$HOME_DIR" ] || { echo "Herdr app home not found: $HOME_DIR (is herdr-app installed and run once?)" >&2; exit 1; }
command -v herdr-app >/dev/null || { echo "herdr-app not on PATH" >&2; exit 1; }

edit_keys() { # edit_keys add|remove
  [ -f "$KEYS" ] || { [ "$1" = add ] && echo '{ "global": {} }' > "$KEYS" || return 0; }
  python3 -I - "$KEYS" "$1" "$KEY" "$CMD" <<'PY'
import json, sys, shutil, time
path, op, key, cmd = sys.argv[1:5]
data = json.load(open(path))
g = data.setdefault("global", {})
if op == "add":
    if key in g and g[key] != cmd:
        print(f"keys.json: {key} already bound to {g[key]}; left alone. Bind {cmd} yourself.")
        sys.exit(0)
    if g.get(key) == cmd:
        sys.exit(0)
    g[key] = cmd
else:
    if g.get(key) != cmd:
        sys.exit(0)
    del g[key]
shutil.copy(path, f"{path}.bak-openrig-{int(time.time())}")
json.dump(data, open(path, "w"), indent=2)
print(f"keys.json: {op} {key}")
PY
}

if [ "$mode" = remove ]; then
  rm -rf "$DEST"
  edit_keys remove
  echo "Removed $DEST"
  exit 0
fi

if [ -d "$DEST" ] && ! diff -rq "$SRC" "$DEST" >/dev/null 2>&1; then
  if [ ! -f "$DEST/main.js" ] || ! grep -q "OpenRig panel" "$DEST/main.js"; then
    [ "$force" = 1 ] || { echo "$DEST exists and is not this mod. Re-run with --force to replace it." >&2; exit 1; }
  fi
fi

mkdir -p "$DEST"
cp "$SRC/main.js" "$SRC/mod.json" "$DEST/"
edit_keys add
herdr-app check "$DEST"
echo "Installed to $DEST. Open with $KEY, or: herdr-app do mod.open --name openrig"
