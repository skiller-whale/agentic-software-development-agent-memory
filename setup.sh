#!/usr/bin/env bash
# Idempotent hosted-environment setup for the agent_memory module.
#
# Runs on every VM boot (startup_commands re-run on reboot), so almost every
# step below is guarded: a learner may already have done exercises, moved
# their own git history forward, or edited their own memory store before a
# reboot, and none of that should be clobbered.
#
# Invoked as: bash "$HOME/$DEFAULT_FOLDER/setup.sh" from exercise_config.yaml's
# startup_commands, with DEFAULT_FOLDER and SW_ATTENDANCE_ID prefixed onto
# that one simple command by the harness (Train/the emulator) — so both reach
# this script as real, inherited environment variables. Nothing below needs
# its own env-var prefix.
set -euo pipefail

REPO_DIR="$HOME/$DEFAULT_FOLDER"

# --- AWS credentials for the Bedrock proxy -----------------------------
# Cheap to rewrite every boot (deterministic content, no learner state to
# clobber), so this one is unguarded.
mkdir -p "$HOME/.aws"
cat << EOF > "$HOME/.aws/credentials"
[swbedrock]

aws_access_key_id=${SW_ATTENDANCE_ID}
aws_secret_access_key=unused
EOF

# --- .zshrc --------------------------------------------------------------
# Also unguarded/rewritten every boot — it's fully deterministic and a
# learner isn't expected to hand-edit their own shell rc for this module.
# LANG/LC_ALL and PATH are exported FIRST, before the PROMPT line: a fresh
# terminal on the real AMI hit `character not in range` on the whale-emoji
# PROMPT line, which aborts sourcing before the PATH export ever runs — so
# plain `claude` wasn't on PATH. Setting a UTF-8 locale up front avoids that,
# and moving PATH up means even if some later line did abort, PATH is safe.
cat << EOF > "$HOME/.zshrc"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PATH="$HOME/.local/bin:$PATH"

export AWS_REGION="eu-west-1"
export ANTHROPIC_MODEL="eu.anthropic.claude-sonnet-5"
export ANTHROPIC_DEFAULT_SONNET_MODEL="eu.anthropic.claude-sonnet-5"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="eu.anthropic.claude-haiku-4-5-20251001-v1:0"
export BEDROCK_MODEL="eu.anthropic.claude-sonnet-5"
export ANTHROPIC_BEDROCK_BASE_URL="https://bedrock-runtime.aws-proxy.skillerwhale.com"
export CLAUDE_CODE_USE_BEDROCK="1"
export AWS_ACCESS_KEY_ID="${SW_ATTENDANCE_ID}"
export AWS_SECRET_ACCESS_KEY="unused"

export PROMPT=\$'%{\e[1m%}🐳 %{\e[1;32m%}%n@%{\e[0m%}:%{\e[1;34m%}%1~%{\e[0m%} \$ '
alias python='python3'
EOF

# --- ~/.claude.json: theme + onboarding + per-project trust -------------
# A learner may have changed other keys in here (model choice, tips, etc.)
# since the last boot, so this is a merge, not an overwrite: load whatever
# is there (or start from {}), only set the specific keys that suppress the
# first-launch dialogs, and write the result back. Safe to run every boot —
# merging is idempotent by construction, unlike a plain overwrite.
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
for project_path in (os.environ["REPO_DIR"] + "/notes-app", os.environ["REPO_DIR"] + "/orders-api"):
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

# --- Claude Code CLI -------------------------------------------------
# Pinned to the version the lab measurements were run against
# (agent-memory-experiments.md) so the module's behavioural claims hold on
# the VM. Guarded: a reboot shouldn't re-fetch and reinstall over the
# network every time when the right version is already there. No sudo on
# the AMI (verified 28 Aug 2026: apt-get fails silently), so this and every
# other install below lands in ~/.local/bin, which the .zshrc above puts on
# PATH.
if ! "$HOME/.local/bin/claude" --version 2>/dev/null | grep -q '^2\.1\.263'; then
  curl -fsSL https://claude.ai/install.sh | bash -s 2.1.263
fi

mkdir -p "$HOME/.claude/projects"
touch "$HOME/.claude/history.jsonl"

# pytest, for the two apps' test suites. Guarded so a reboot doesn't hit the
# network (and the package index) every time it's already installed.
if ! python3 -m pytest --version >/dev/null 2>&1; then
  pip3 install --user pytest
fi

# --- notes-app / orders-api: git history, in place ----------------------
# The editor's workspace root is the cloned public repo ($REPO_DIR), so the
# two projects stay where they were cloned and become the top-level folders
# the learner sees. Each gets its own git history (auto memory is keyed by
# the nearest git root, so each project gets its own store). The outer
# clone's .git is removed so the workspace is a plain folder and the two
# projects are not embedded repos inside another repo. Guarded so a VM
# reboot doesn't rewrite a learner's own history.
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
  # Commit 1: the health endpoint as first built, at /status.
  sed -i "s#self.path == \"/health\"#self.path == \"/status\"#" app.py
  git add -A
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -m "Initial orders-api"
  # Commit 2: renamed to /health — this is the commit the seeded
  # health-check-endpoint.md memory (still saying /status) is stale against.
  sed -i "s#self.path == \"/status\"#self.path == \"/health\"#" app.py
  git -c user.email="learner@example.com" -c user.name="Learner" commit -q -am "Rename /status to /health"
fi

# --- Memory store keys ----------------------------------------------------
# Claude Code keys a project's auto-memory store by its git root path with
# every "/" replaced by "-": ~/.claude/projects/<key>/memory/.
NOTES_KEY="$(printf '%s' "$REPO_DIR/notes-app" | sed 's#/#-#g')"
ORDERS_KEY="$(printf '%s' "$REPO_DIR/orders-api" | sed 's#/#-#g')"
NOTES_STORE="$HOME/.claude/projects/$NOTES_KEY/memory"
ORDERS_STORE="$HOME/.claude/projects/$ORDERS_KEY/memory"

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
mkdir -p "$NOTES_STORE"

# --- Memory folders visible in the editor's file explorer ----------------
# ~/.claude/projects/<key>/memory/ is a dot-directory outside the workspace,
# so learners can't browse it from the file explorer. Symlink each store
# into the workspace under a plain name; the module's checklists refer to
# these names. Guarded on the link itself so a reboot doesn't error.
[ -L "$REPO_DIR/notes-app-memory" ] || ln -s "$NOTES_STORE" "$REPO_DIR/notes-app-memory"
[ -L "$REPO_DIR/orders-api-memory" ] || ln -s "$ORDERS_STORE" "$REPO_DIR/orders-api-memory"

# --- Hide the plumbing from the explorer ----------------------------------
# seed-store/ and this script stay on disk (a reboot re-runs setup.sh from
# here) but have no business in the learner's view of the workspace.
mkdir -p "$REPO_DIR/.vscode"
cat << EOF > "$REPO_DIR/.vscode/settings.json"
{
    "files.exclude": {
        "seed-store": true,
        "setup.sh": true,
        ".vscode": true
    }
}
EOF
