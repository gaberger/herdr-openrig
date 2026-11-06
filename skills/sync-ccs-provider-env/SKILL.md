---
name: sync-ccs-provider-env
description: Use when an OpenRig-managed Claude Code seat says "Not logged in" under a ccs profile that uses Bedrock, Vertex or Foundry, when a seat shows idle but cannot answer, or before launching a rig from a ccs provider profile.
---

# Make ccs provider profiles reach OpenRig seats

A ccs profile picks its provider with variables such as `CLAUDE_CODE_USE_BEDROCK`
and `AWS_PROFILE`. `ccs <profile>` exports them into the `claude` it starts.
OpenRig seats are started by the daemon instead, and the daemon passes a seat
only `CLAUDE_CONFIG_DIR` plus a fixed list of credential names. Those provider
variables are not on the list, so the seat's Claude falls back to an Anthropic
login and prints `Not logged in`, even though the daemon was started under the
profile. `rig ps` still shows the seat `running` and `idle`, and `rig doctor`
reports auth from your own shell, so neither shows the fault.

Claude Code applies the `env` block of `settings.json` in `CLAUDE_CONFIG_DIR` at
startup, and seats do receive that directory. This skill copies the profile's
provider variables into that block.

**This profile does not use a Claude account** when `CLAUDE_CODE_USE_*` is set.
`/login` and `claude auth login` do not apply; Bedrock uses AWS credentials for
`AWS_PROFILE` (`aws sso login --profile <name>` if the session expired).

## Steps

1. Check first; this changes nothing:
   ```bash
   bash scripts/sync.sh --check            # resolved profile, or: sync.sh <profile> --check
   ```
   Exit 1 means the profile is out of sync.
2. Apply:
   ```bash
   bash scripts/sync.sh                    # adds missing names, backs up settings.json
   ```
   A value that already differs is left alone and reported; `--force` overwrites it.
3. Relaunch each Claude seat so the new process reads the file. A running Claude
   does not re-read it. For a seat, `rig seat stop <session> --reason "<why>"`
   then `rig launch <rig> <node>` resumes it from its snapshot.
4. Verify with a real turn, not a status: `rig capture <session>` must no longer
   show `Not logged in`, and the seat must answer a short `rig send`.

## Notes

- Only provider-selection names are copied (`CLAUDE_CODE_USE_*`, `AWS_PROFILE`,
  `AWS_REGION`, `ANTHROPIC_BASE_URL` and the `ANTHROPIC_*MODEL` names). Keys and
  tokens are never copied, and values are never printed.
- It edits the profile's `settings.json`, which every session on that profile
  reads. The values match what `ccs env` already gives your own terminal.
- Re-run after `ccs import aws` or any edit to a profile's `profile.env`.
- A `.bak-ccs-sync-<time>` copy of `settings.json` is written before each change.
