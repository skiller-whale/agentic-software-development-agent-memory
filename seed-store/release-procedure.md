---
name: release-procedure
description: The release procedure for this service
metadata:
  node_type: memory
  type: project
  originSessionId: 66666666-6666-4666-8666-666666666666
  modified: 2026-08-01T10:25:00.000Z
---

Release procedure: bump the version in `config.py`, tag `vX.Y.Z`, push tags; CI builds the image.

**Why:** that's how this service's releases are cut and published.

**How to apply:** when asked to cut a release, bump the version in `config.py`, create and push a `vX.Y.Z` tag, and let CI build the image from it.
