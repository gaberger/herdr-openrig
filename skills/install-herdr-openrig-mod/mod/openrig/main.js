// OpenRig panel: rigs and their seats from `rig ps --json`.
// Click a seat to attach to its tmux session in a new tab; "view" asks OpenRig
// to place the rig's tiles in Herdr (`rig terminal open <rig> --provider herdr`).
// Runs programs: `rig`. Reads nothing outside its own folder.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, run, theme, closeOverlay, props, notify } from "herdr";

// Herdr's exec has a thin PATH (no nvm), so find `rig` once through an
// interactive shell, cache it, and run it with its own directory on PATH.
let rigPath = localStorage.getItem("rigPath");
async function findRig() {
  if (rigPath) return rigPath;
  const r = await exec("/bin/zsh", ["-ic", "command -v rig"]);
  const found = r.stdout.trim().split("\n").pop();
  if (r.code !== 0 || !found.startsWith("/")) throw new Error("Can't find `rig`. Install OpenRig, or set rigPath in localStorage.");
  localStorage.setItem("rigPath", found);
  return (rigPath = found);
}

async function run_rig(args) {
  const bin = await findRig();
  const dir = bin.slice(0, bin.lastIndexOf("/"));
  return exec("/usr/bin/env", [`PATH=${dir}:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`, bin, ...args]);
}

async function rig(args) {
  const r = await run_rig(args);
  if (r.code !== 0) throw new Error((r.stderr || r.stdout || `rig exited ${r.code}`).trim());
  return JSON.parse(r.stdout);
}

// A seat's status in Herdr's vocabulary.
function status(seat) {
  if (seat.sessionStatus !== "running") return "unknown";
  if (seat.needsAttention) return "blocked";
  return seat.agentActivity?.state === "working" ? "working" : "idle";
}

export default class OpenRig extends View {
  init(_props, cx) {
    this.rigs = [];
    this.seats = {}; // rig name -> seats
    this.folded = new Set();
    this.error = null;
    this.loaded = false;
    cx.timer.every(5000, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      try {
        const rigs = (await rig(["ps", "--json"])).filter((r) => !r.isArchived);
        const seats = {};
        for (const r of rigs) seats[r.name] = await rig(["ps", "--nodes", "--rig", r.name, "--json"]);
        this.rigs = rigs;
        this.seats = seats;
        this.error = null;
      } catch (e) {
        this.error = String(e.message ?? e);
      }
      this.loaded = true;
      cx.notify();
    });
  }

  attach(seat) {
    closeOverlay(props().overlay);
    run("tab.new", {
      name: seat.logicalId,
      argv: ["env", "-u", "TMUX", "tmux", "attach", "-t", seat.canonicalSessionName],
    });
  }

  openView(name, cx) {
    cx.spawn(async () => {
      const r = await run_rig(["terminal", "open", name, "--provider", "herdr"]);
      if (r.code !== 0) notify({ title: `rig terminal open ${name}`, body: (r.stderr || r.stdout).trim().slice(0, 300), level: "error" });
    });
  }

  render(cx) {
    const t = theme();
    const dot = (s) => div().w(8).h(8).rounded(4).flex_none().bg(t[s] ?? t.unknown);

    const seatRow = (s) => {
      const st = status(s);
      return h_flex().id(`seat-${s.canonicalSessionName}`).gap(8).items_center().px(10).py(4).pl(26)
        .hover((h) => h.bg(t.hover))
        .on_click(() => this.attach(s))
        .child(dot(st))
        .child(div().flex_1().truncate().text_color(t.foreground).child(s.logicalId))
        .child(div().text_color(t.dim).text_size(11).child(s.runtime ?? ""))
        .child(div().w(54).text_color(t[st] ?? t.muted).text_size(11).child(st));
    };

    const rigBlock = (r) => {
      const open = !this.folded.has(r.name);
      return v_flex().id(`rig-${r.name}`).child(
        h_flex().id(`rig-head-${r.name}`).gap(8).items_center().px(10).py(6).bg(t.raised)
          .on_click(() => { open ? this.folded.add(r.name) : this.folded.delete(r.name); cx.notify(); })
          .child(div().w(10).text_color(t.dim).child(open ? "▾" : "▸"))
          .child(div().flex_1().font_semibold().text_color(t.foreground).child(r.name))
          .child(div().text_size(11).text_color(r.attentionCount ? t.blocked : t.muted)
            .child(`${r.runningCount}/${r.nodeCount} running${r.attentionCount ? ` · ${r.attentionCount} need you` : ""}`))
          .child(div().id(`view-${r.name}`).px(8).py(2).rounded(4).text_size(11).text_color(t.accent)
            .hover((h) => h.bg(t.hover))
            .on_click((_e, cx) => this.openView(r.name, cx))
            .child("view")),
      ).children(open ? (this.seats[r.name] ?? []).map(seatRow) : []);
    };

    return v_flex().size_full().bg(t.popover).text_size(13).child(
      h_flex().px(10).py(8).items_center().child(div().flex_1().font_semibold().text_color(t.foreground).child("OpenRig"))
        .child(div().id("refresh").px(8).py(2).rounded(4).text_size(11).text_color(t.muted)
          .hover((h) => h.bg(t.hover)).on_click((_e, cx) => this.refresh(cx)).child("refresh")),
    ).child(
      v_flex().flex_1().overflow_y_scrollbar().gap(2)
        .when(this.error, (el) => el.child(div().p(10).text_color(t.blocked).child(this.error)))
        .when(!this.error && this.loaded && !this.rigs.length, (el) => el.child(div().p(10).text_color(t.muted).child("No rigs running. Start one with: rig up <spec>")))
        .when(!this.loaded, (el) => el.child(div().p(10).text_color(t.muted).child("Loading…")))
        .children(this.rigs.map(rigBlock)),
    );
  }
}
