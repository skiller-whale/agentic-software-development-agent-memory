#!/usr/bin/env bash
# Idempotent hosted-environment setup for the agent_memory module.
#
# Runs on every VM boot (startup_commands re-run on reboot), so almost every
# step below is guarded: a learner may already have done exercises, moved
# their own git history forward, or edited their own memory store before a
# reboot, and none of that should be clobbered.
#
# Invoked as: bash "$HOME/$DEFAULT_FOLDER/setup.sh" from exercise_config.yaml's
# startup_commands, AFTER the shared `!include* ai/hle_claude_setup.yaml`
# commands (AWS credentials, Bedrock env in .zshrc, the extension's .vscode
# settings, .claude.json theme, the CLI install). DEFAULT_FOLDER and
# SW_ATTENDANCE_ID are prefixed onto that one simple command by the harness
# (Train/the emulator) — so both reach this script as real, inherited
# environment variables. Nothing below needs its own env-var prefix.
set -euo pipefail

REPO_DIR="$HOME/$DEFAULT_FOLDER"

# --- Shell extras --------------------------------------------------------
# The shared ai/hle_claude_setup.yaml (spliced into startup_commands before
# this script) rewrites ~/.zshrc with the Bedrock/model exports every boot.
# This appends what the module needs on top. LANG/LC_ALL first: a fresh
# terminal on the real AMI hit `character not in range` on the whale-emoji
# PROMPT line, which aborts sourcing before anything after it runs. Guarded
# by a marker so a re-run without the shared rewrite doesn't duplicate it.
if ! grep -q '# agent_memory shell extras' "$HOME/.zshrc" 2>/dev/null; then
  cat << EOF >> "$HOME/.zshrc"

# agent_memory shell extras
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PATH="$HOME/.local/bin:\$PATH"
export PROMPT=\$'%{\e[1m%}🐳 %{\e[1;32m%}%n@%{\e[0m%}:%{\e[1;34m%}%1~%{\e[0m%} \$ '
alias python='python3'
EOF
fi

# --- ~/.claude.json: onboarding + per-project trust ----------------------
# The shared setup writes this file with just the theme. A learner may also
# have changed keys in here (model choice, tips, etc.) since the last boot,
# so this is a merge, not an overwrite: load whatever is there (or start
# from {}), only set the specific keys that suppress the first-launch
# dialogs, and write the result back. Safe to run every boot — merging is
# idempotent by construction, unlike a plain overwrite.
REPO_DIR="$REPO_DIR" python3 - << 'PYEOF'
import json
import os

path = os.path.expanduser("~/.claude.json")
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

# Theme picker: only set if the learner hasn't already chosen one.
data.setdefault("theme", "light")

# First-launch onboarding wizard.
data["hasCompletedOnboarding"] = True

# "Recommended terminal settings" prompt (shift+enter keybinding etc.) —
# offered for TERM_PROGRAM=vscode among others, so it fires in the editor's
# integrated terminal. Only set if absent, so we don't fight a learner who
# explicitly declined it.
data.setdefault("shiftEnterKeyBindingInstalled", True)

# Per-project "trust this folder?" dialog, once per repo per session.
projects = data.setdefault("projects", {})
for project in ("notes-app", "orders-api", "url-shortener"):
    project_path = os.environ["REPO_DIR"] + "/" + project
    project = projects.setdefault(project_path, {})
    project["hasTrustDialogAccepted"] = True

with open(path, "w") as f:
    json.dump(data, f, indent=4)
PYEOF

# --- Claude Code user settings: start learners in auto mode -------------
# Has to be user settings — `auto` is ignored from a project's
# .claude/settings.json. Deterministic content, unguarded.
mkdir -p "$HOME/.claude"
cat << EOF > "$HOME/.claude/settings.json"
{
    "permissions": {
        "defaultMode": "auto"
    }
}
EOF

# --- Claude Code CLI version pin ------------------------------------------
# The shared setup installs the latest CLI. This module's behavioural claims
# were measured on 2.1.263 (agent-memory-experiments.md), so if the shared
# install produced anything else, install the pinned build over it. Guarded,
# so a reboot with the right version already there does nothing. No sudo on
# the AMI (verified 28 Aug 2026), so this lands in ~/.local/bin like the
# shared install does.
if ! "$HOME/.local/bin/claude" --version 2>/dev/null | grep -q '^2\.1\.263'; then
  curl -fsSL https://claude.ai/install.sh | bash -s 2.1.263
fi

# pytest, for the projects' test suites. Guarded so a reboot doesn't hit the
# network (and the package index) every time it's already installed.
if ! python3 -m pytest --version >/dev/null 2>&1; then
  pip3 install --user pytest
fi

# --- notes-app / orders-api / url-shortener: git history, in place --------
# The editor's workspace root is the cloned public repo ($REPO_DIR), so the
# projects stay where they were cloned and become the top-level folders the
# learner sees. Each gets its own git history (auto memory is keyed by the
# nearest git root, so each project gets its own store). The outer clone's
# .git is removed so the workspace is a plain folder and the projects are
# not embedded repos inside another repo. Guarded so a VM reboot doesn't
# rewrite a learner's own history.
rm -rf "$REPO_DIR/.git"

if [ ! -d "$REPO_DIR/notes-app/.git" ]; then
  cd "$REPO_DIR/notes-app"
  git init -q -b main
  git add -A
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -m "Initial notes-app"
fi

if [ ! -d "$REPO_DIR/orders-api/.git" ]; then
  cd "$REPO_DIR/orders-api"
  git init -q -b main
  # Commit 1: the health endpoint as first built, at /status (all three
  # branches of the duplicated handler — hence the global replace).
  sed -i "s#/health#/status#g" app.py
  git add -A
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -m "Initial orders-api"
  # Commit 2: renamed to /health — this is the commit the seeded
  # health-check-endpoint.md memory (still saying /status) is stale against.
  sed -i "s#/status#/health#g" app.py
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -am "Rename /status to /health"
fi

# url-shortener is the prompt-injection project (ex 4): its README carries
# the note addressed to AI agents, and nothing else of interest, so the
# note can't be tripped over during the orders-api exercises. Its memory
# store starts empty.
if [ ! -d "$REPO_DIR/url-shortener/.git" ]; then
  cd "$REPO_DIR/url-shortener"
  git init -q -b main
  git add -A
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -m "Initial url-shortener"
fi

# --- Memory store keys ----------------------------------------------------
# Claude Code keys a project's auto-memory store by its git root path with
# every "/" replaced by "-": ~/.claude/projects/<key>/memory/.
NOTES_KEY="$(printf '%s' "$REPO_DIR/notes-app" | sed 's#/#-#g')"
ORDERS_KEY="$(printf '%s' "$REPO_DIR/orders-api" | sed 's#/#-#g')"
SHORTENER_KEY="$(printf '%s' "$REPO_DIR/url-shortener" | sed 's#/#-#g')"
NOTES_STORE="$HOME/.claude/projects/$NOTES_KEY/memory"
ORDERS_STORE="$HOME/.claude/projects/$ORDERS_KEY/memory"
SHORTENER_STORE="$HOME/.claude/projects/$SHORTENER_KEY/memory"

# --- Seed orders-api's memory store --------------------------------------
# Nine notes from earlier (measured, verified) sessions. Old mtimes (not the
# frontmatter `modified` field, which the harness ignores for this) trigger
# the "This memory is N days old" reminder on Read. Guarded so a reboot
# doesn't re-stamp files the learner's agent has since corrected, and so it
# NEVER overwrites a store the learner has changed.
if [ ! -d "$ORDERS_STORE" ]; then
  mkdir -p "$ORDERS_STORE"
  cp "$REPO_DIR/seed-store"/*.md "$ORDERS_STORE/"
  touch -t 202608011200 "$ORDERS_STORE"/*.md
fi
mkdir -p "$NOTES_STORE" "$SHORTENER_STORE"

# --- Memory folders visible in the editor's file explorer ----------------
# ~/.claude/projects/<key>/memory/ is a dot-directory outside the workspace,
# so learners can't browse it from the file explorer. Symlink each store
# into the workspace under a plain name; the module's checklists refer to
# these names. Guarded on the link itself so a reboot doesn't error.
[ -L "$REPO_DIR/notes-app-memory" ] || ln -s "$NOTES_STORE" "$REPO_DIR/notes-app-memory"
[ -L "$REPO_DIR/orders-api-memory" ] || ln -s "$ORDERS_STORE" "$REPO_DIR/orders-api-memory"
[ -L "$REPO_DIR/url-shortener-memory" ] || ln -s "$SHORTENER_STORE" "$REPO_DIR/url-shortener-memory"

# --- Hide the plumbing from the explorer ----------------------------------
# seed-store/ and this script stay on disk (a reboot re-runs setup.sh from
# here) but have no business in the learner's view of the workspace. The
# shared setup has already written .vscode/settings.json with the Claude
# Code extension's settings, so this merges files.exclude into it rather
# than overwriting.
mkdir -p "$REPO_DIR/.vscode"
REPO_DIR="$REPO_DIR" python3 - << 'PYEOF'
import json
import os
import re

path = os.path.join(os.environ["REPO_DIR"], ".vscode", "settings.json")
# The shared setup's settings.json carries a trailing comma (fine for VS
# Code's JSONC parser, fatal for json.load), so strip trailing commas
# before giving up — losing the file would drop the extension's Bedrock
# config, and the extension would then ask the learner to log in.
try:
    with open(path) as f:
        raw = f.read()
except FileNotFoundError:
    raw = ""
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    try:
        data = json.loads(re.sub(r",\s*([\]}])", r"\1", raw))
    except json.JSONDecodeError:
        data = {}

data.setdefault("files.exclude", {}).update({
    "seed-store": True,
    "setup.sh": True,
    ".vscode": True,
})

with open(path, "w") as f:
    json.dump(data, f, indent=4)
PYEOF
