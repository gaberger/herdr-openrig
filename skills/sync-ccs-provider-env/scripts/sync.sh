#!/usr/bin/env bash
# Copy a ccs profile's provider-selection variables into that profile's
# settings.json "env" block, so processes that only inherit CLAUDE_CONFIG_DIR
# (OpenRig-managed seats) still reach the provider.
#
#   sync.sh [<profile>] [--check] [--force]
#
#   <profile>  ccs profile name; default is the one `ccs which` resolves.
#   --check    report drift, change nothing; exit 1 if the profile is out of sync.
#   --force    overwrite a settings.json value that differs from the profile.
#
# Source of truth is `ccs env <profile>`, so this follows whatever ccs resolves.
# Only the provider-selection names ccs itself manages are copied, never keys or
# tokens. Existing settings are never removed; a differing value is left alone
# unless --force. Values are never printed, only names.
set -euo pipefail

profile="" check=0 force=0
for a in "$@"; do
  case "$a" in
    --check) check=1 ;;
    --force) force=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "unknown arg: $a" >&2; exit 2 ;;
    *) [ -z "$profile" ] && profile="$a" || { echo "one profile only" >&2; exit 2; } ;;
  esac
done

command -v ccs >/dev/null || { echo "ccs not on PATH" >&2; exit 1; }
[ -n "$profile" ] || profile="$(ccs which)"
[ -n "$profile" ] || { echo "no ccs profile resolved; pass one" >&2; exit 1; }

ccs env "$profile" 2>/dev/null | python3 -I -c '
import json, os, re, shlex, shutil, sys, time

profile, check, force = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"
# The provider-selection names `ccs env` unsets and sets; credentials are not among them.
NAMES = {
    "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
    "AWS_PROFILE", "AWS_REGION", "ANTHROPIC_BASE_URL", "ANTHROPIC_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL",
    "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
}
want, config_dir = {}, None
for line in sys.stdin:
    m = re.match(r"export ([A-Z_][A-Z0-9_]*)=(.*)$", line.strip())
    if not m:
        continue
    name, raw = m.group(1), m.group(2)
    try:
        val = shlex.split(raw)[0] if raw else ""
    except ValueError:
        continue
    if name == "CLAUDE_CONFIG_DIR":
        config_dir = val
    elif name in NAMES and val:
        want[name] = val

if not config_dir:
    sys.exit(f"ccs env {profile}: no CLAUDE_CONFIG_DIR; is the profile name right?")
if not want:
    print(f"{profile}: no provider variables to sync (a Claude-account profile needs none).")
    sys.exit(0)

path = os.path.join(config_dir, "settings.json")
data = json.load(open(path)) if os.path.exists(path) else {}
env = data.setdefault("env", {})

add = sorted(n for n in want if n not in env)
differ = sorted(n for n in want if n in env and env[n] != want[n])
same = sorted(n for n in want if n in env and env[n] == want[n])
change = add + (differ if force else [])

print(f"profile {profile}: {path}")
if same:   print("  already set:   " + ", ".join(same))
if add:    print("  missing:       " + ", ".join(add))
if differ: print("  differs:       " + ", ".join(differ) + ("" if force else "  (left alone; --force to overwrite)"))

if check:
    sys.exit(1 if (add or differ) else 0)
if not change:
    print("  nothing to do")
    sys.exit(0)

if os.path.exists(path):
    shutil.copy2(path, f"{path}.bak-ccs-sync-{int(time.time())}")
for n in change:
    env[n] = want[n]
os.makedirs(config_dir, exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  wrote:         " + ", ".join(change))
' "$profile" "$check" "$force"
