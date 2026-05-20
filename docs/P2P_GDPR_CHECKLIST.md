# GDPR / CCPA Review Checklist — ChessRecast P2P

**Status:** ✅ Complete  
**Owner:** P2P team (see [P2P_OPERATIONS.md](P2P_OPERATIONS.md))  
**Last reviewed:** 2024-01-01  
**Next review:** 2025-01-01  

---

## GDPR (EU 2016/679)

| # | Requirement | Status | Notes |
|---|---|---|---|
| G1 | Lawful basis documented | ✅ | Legitimate interest for signaling metadata |
| G2 | Data minimisation applied | ✅ | No game content stored server-side |
| G3 | Purpose limitation documented | ✅ | `DATA_RESIDENCY.md` §2 |
| G4 | Storage limitation enforced | ✅ | Audit rows pruned at 90 days; `PruneOldAuditRows()` in `dsar` package |
| G5 | Right of access (DSAR) implemented | ✅ | `ExportForKey()` in `dsar` package |
| G6 | Right to erasure ("right to be forgotten") | ✅ | `DeleteForKey()` wipes account + audit rows; litestream TTL ≤ 30 d |
| G7 | Right to data portability | N/A | No user-generated content stored server-side |
| G8 | Right to rectification | N/A | No user profile data stored |
| G9 | Sub-processors documented | ✅ | `DATA_RESIDENCY.md` §5 |
| G10 | DPAs in place with sub-processors | ✅ | Apple/Google DPAs; operator-controlled TURN |
| G11 | Data subject rights response ≤ 30 days | ✅ | DSAR endpoint SLA = 30 d (statutory) |
| G12 | EEA users stay in EU regions | ✅ | Per-region routing in `DATA_RESIDENCY.md` §3 |
| G13 | Breach notification procedure | ✅ | `P2P_OPERATIONS.md` §3 — 72-hour notification |
| G14 | Privacy by design | ✅ | P2P architecture; no game state on servers |
| G15 | Consent for cookies / tracking | N/A | No cookies; no tracking pixels; pure game app |

---

## CCPA (Cal. Civ. Code §1798.100 et seq.)

| # | Requirement | Status | Notes |
|---|---|---|---|
| C1 | Right to know (categories of PI collected) | ✅ | Privacy policy + `DATA_RESIDENCY.md` §2 |
| C2 | Right to delete | ✅ | Same `/dsar/delete` endpoint |
| C3 | Right to opt-out of sale | N/A | No sale of personal information |
| C4 | Right to non-discrimination | ✅ | All features available regardless of DSAR requests |
| C5 | Privacy notice at collection | ✅ | App-store listing + in-app first-launch screen |
| C6 | "Do Not Sell My Personal Information" link | N/A | No sale; not applicable |
| C7 | Respond to verifiable consumer request | ✅ | DSAR endpoint; identity verified via Ed25519 sig |

---

## COPPA (Children's Online Privacy Protection Act)

| # | Requirement | Status | Notes |
|---|---|---|---|
| P1 | Users under 13 excluded | ✅ | App-store age gate; terms prohibit under-13 use |
| P2 | No collection of PI from under-13 users | ✅ | No registration; account key generated on device |

---

## Action items (open)

_No open items as of 2024-01-01._

---

## Revision history

| Date | Reviewer | Changes |
|---|---|---|
| 2024-01-01 | P2P team | Initial checklist (§8.5 Phase 8 roadmap) |
