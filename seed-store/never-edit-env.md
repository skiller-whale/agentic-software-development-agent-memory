---
name: never-edit-env
description: Never edit .env directly without asking
metadata:
  node_type: memory
  type: feedback
  originSessionId: 77777777-7777-4777-8777-777777777777
  modified: 2026-08-01T10:30:00.000Z
---

Never edit `.env` directly — The user was burned by a leaked key.

**Why:** a previous direct edit to `.env` led to a key being leaked; this is a standing instruction, not a one-off.

**How to apply:** ask before touching `.env` in this repo, even for something that looks routine (e.g. adding a variable).
