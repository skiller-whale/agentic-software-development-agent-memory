---
name: payments-sandbox-keys
description: Payment provider sandbox keys are rotated monthly by ops
metadata:
  node_type: memory
  type: reference
  originSessionId: 11111111-1111-4111-8111-111111111111
  modified: 2026-08-01T10:00:00.000Z
---

Payment provider sandbox keys are rotated monthly by ops.

**Why:** ops rotates sandbox credentials on a schedule for security; a stale key in `.env` will start failing auth without any code change.

**How to apply:** if payment calls start failing with an auth error, ask in #payments for the current sandbox key before assuming it's a code bug.
