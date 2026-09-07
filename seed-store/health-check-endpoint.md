---
name: health-check-endpoint
description: The health check endpoint path
metadata:
  node_type: memory
  type: project
  originSessionId: 22222222-2222-4222-8222-222222222222
  modified: 2026-08-01T10:05:00.000Z
---

The health check endpoint is `/healthz`.

**Why:** that's the path the service exposes for liveness checks.

**How to apply:** when wiring up monitoring or curling the service to check it's up, use `/healthz`.
