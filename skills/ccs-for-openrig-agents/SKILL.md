---
name: ccs-for-openrig-agents
description: Use when an agent in an OpenRig seat meets ccs (Claude Code profile switcher), a ccs profile or kit, or needs to add a skill, plugin or MCP server for a ccs user; or when a Claude seat says "Not logged in" and the profile may use Bedrock, Vertex or Foundry.
---

# Working with ccs from an OpenRig seat

`ccs` is a Claude Code profile switcher. A **profile** is a login (provider
variables, config dir, settings). A **kit** is a set of skills, agents and
instructions. A launch is a profile plus kits. Everything lives under
`$CCS_HOME` (default `~/.claude-profiles`). `ccs --help` has the full surface.

## Read first, change later

These are read-only; run them before anything else:

- `ccs list` shows profiles and kits (`*` marks the resolved one); `ccs which`
  prints the resolved profile. Resolution order: argument, `.claude-profile`
  (walking up from the cwd), `$CCS_PROFILE`, then the default.
- `ccs doctor [<profile>]` checks a profile and its kits; `ccs loads [<profile>]`
  shows what it loads and builds nothing.
- `ccs env [<profile>]` prints the exports a shell needs to act as that profile.
  Never print, log or store the values of credential variables; name the
  variables, not their contents.

Ask the person before `ccs new`, `migrate`, `upgrade`, `kit rm` or `library rm`.

## Adding things so a profile actually loads them

Skills, agents and plugins go into the ccs **library** (`ccs library add`) and
reach a profile through a **kit** (`ccs kit use`, `ccs kit attach`). Copying into
`~/.claude/skills`, a plain `claude plugin install`, or `claude mcp add -s user`
writes where no ccs profile reads: it looks like it worked and does nothing.
Start a new session afterwards; skills load at launch.

## A seat says "Not logged in"

First find out what kind of profile it is. If `ccs env` shows
`CLAUDE_CODE_USE_BEDROCK`, `_VERTEX` or `_FOUNDRY`, the profile does not use a
Claude account: `/login` and `claude auth login` do not apply, so do not send
the person there. Bedrock authenticates through AWS credentials for
`AWS_PROFILE`; an expired SSO session is fixed with
`aws sso login --profile <name>`, which is the person's to run.

Otherwise the cause is usually that the seat's Claude process never received the
profile's variables. OpenRig's daemon passes a seat only `CLAUDE_CONFIG_DIR` and
a fixed list of credential names, so `CLAUDE_CODE_USE_*` and `AWS_PROFILE` do not
reach it, however the daemon was started. Use the `sync-ccs-provider-env` skill:
`sync.sh --check`, then `sync.sh`, then relaunch the Claude seats.

Do not trust the usual signals here. `rig ps` can show a seat `running` and
`idle` while it cannot answer, and `rig doctor` reports auth from your own
shell, not the seat's process. Confirm with `rig capture <session>` (no
`Not logged in`) and a short `rig send` that gets an answer.
