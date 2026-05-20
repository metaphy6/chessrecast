# P2P Deprecation Events

This document records all wire-protocol deprecation events for Chess Recast P2P,
as required by §16.5.4 of the P2P Roadmap. Each entry documents the soft-
deprecation announcement, the hard-deprecation enforcement date, and the original
release-notes link.

The deprecation ladder (§16.5.1–16.5.3):

| Stage | Action | Sunset window |
|---|---|---|
| **Soft-deprecate** | Announce in release notes; bump `min_*` on staging; show non-blocking "please update" badge for 30 d | — |
| **Hard-deprecate** | Bump `min_*` on production; affected clients receive `DEPRECATED_*_REJECTED` + store deep-link | — |
| **Sunset gap** | `wire_version` / `crypto_suite_id`: ≥ 90 d between soft and hard | — |
| **Sunset gap** | `engine_replay_version`: ≥ 30 d between soft and hard (rule bugs justify shorter) | — |

---

## Active deprecation entries

*No entries yet — first P2P release has not shipped.*

---

## Retired entries

*None.*

---

## How to add an entry

When soft-deprecating a protocol field:

1. Announce in the release notes for the version that introduces the newer
   alternative.
2. Record a new entry in this file with:
   - `field`: the deprecated field name
   - `wire_version_added`: the version at which the field was introduced
   - `soft_deprecate_version`: the version announcing the deprecation
   - `soft_deprecate_date`: ISO 8601 date
   - `hard_deprecate_date_earliest`: soft_deprecate_date + 90 d (wire/crypto)
     or + 30 d (engine_replay_version)
   - `hard_deprecate_version`: the version enforcing the floor
   - `hard_deprecate_date`: ISO 8601 date (must be ≥ hard_deprecate_date_earliest)
   - `release_notes_link`: URL to the GitHub release entry
   - `replacement`: the field / mechanism that supersedes it

3. When hard-deprecating, update the `hard_deprecate_version` and
   `hard_deprecate_date` fields.

### Entry template (YAML)

```yaml
- field: wire_version
  wire_version_added: "1"
  soft_deprecate_version: "x.y.z"
  soft_deprecate_date: "YYYY-MM-DD"
  hard_deprecate_date_earliest: "YYYY-MM-DD"  # + 90 d for wire/crypto
  hard_deprecate_version: "x.y.z"
  hard_deprecate_date: "YYYY-MM-DD"
  release_notes_link: "https://github.com/chessrecast/chessrecast/releases/tag/vX.Y.Z"
  replacement: "wire_version 2 (see P2P_PROTOCOL.md §wire-version)"
```
