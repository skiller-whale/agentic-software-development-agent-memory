---
name: mobile-client-retries
description: The mobile client's retry behaviour on order failures
metadata:
  node_type: memory
  type: project
  originSessionId: 99999999-9999-4999-8999-999999999999
  modified: 2026-08-01T10:40:00.000Z
---

The mobile client retries failed requests with exponential backoff (up to 5 attempts), so the API can safely return 503 on transient payment failures.

**Why:** confirmed by the mobile team — the client already handles retrying transient failures, so the API doesn't need to implement its own retry logic for those cases.

**How to apply:** when the payment provider is briefly unavailable, it's fine for `POST /orders` to return 503 and let the mobile client's own retry-with-backoff handle it; don't add server-side retry logic to compensate.
