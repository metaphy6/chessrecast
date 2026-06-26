# P2P Cryptographic Protocol Audit — Engagement Scope

> **Roadmap reference:** [docs/p2p/P2P_ROADMAP.md](P2P_ROADMAP.md) § Phase 15.1  
> **Status:** Scope document ready — engagement to be commissioned before GA gate.  
> **Audited commit SHA:** TBD (to be recorded here when the audit is commissioned).

---

## 1. Engagement Overview

Chess Recast invites a qualified third-party cryptographic-protocol firm to audit
the P2P communication layer before the General Availability release. The purpose
is independent validation of protocol soundness, key management correctness, and
resistance to known cryptographic attacks.

The engagement is **not** dependent on beta launch and runs in parallel with the
Phase 6 beta period. It is a **hard prerequisite** for the Phase 6 §6.4 GA-rollout
gate.

The audit firm is engaged for its time and expertise; an "all-clear" outcome is
acceptable and publishable. Findings are tracked per the severity ladder in §4 of
this document.

---

## 2. Cryptographic Protocol Scope

The following documents and code sections are in scope:

| Artefact | Description |
|---|---|
| [docs/p2p/P2P_PROTOCOL.md](P2P_PROTOCOL.md) v1 | Full wire-protocol specification. |
| Phase 1 — Wire protocol (CBOR over SCTP DataChannel) | Framing, CBOR encoding, frame-size caps. |
| Phase 2 — Identity, key management and recovery | Ed25519 identity keys, X3DH-style handshake, sealed sessions. |
| Phase 11 — Chess clock and time control | Clock message signing and replay protection. |
| Phase 12 — Engine replay / version pinning | Replay-log integrity, version-pinned engine binding. |

### 2.1 Protocol soundness review areas

The written report **must** cover at minimum:

| Topic | Specific concern |
|---|---|
| **Forward secrecy** | Do ephemeral keys prevent compromise of past sessions if a long-term key leaks? |
| **Replay protection** | Are nonce/counter schemes sufficient to detect and reject replayed messages? |
| **Downgrade resistance** | Can an on-path attacker force a weaker `crypto_suite_id` or `wire_version`? |
| **KDF parameter choice** | Are HKDF domain-separation labels, salt handling, and output lengths correct? |
| **AEAD nonce construction** | Are nonces unique per (key, direction, session)? Is counter overflow handled? |
| **AEAD algorithm choice** | Is the selected AEAD appropriate for the traffic volume and key lifetime? |
| **Signature ceremonies** | Are Ed25519 signatures applied to the correct canonical byte sequence? |
| **Identity binding** | Can a relay or MITM substitute a different public key undetected? |
| **Key rotation** | Does the rotation ceremony preserve forward secrecy and revoke old session state? |

---

## 3. Deliverables

The engagement produces a **written report** that includes:

1. **Protocol soundness assessment** — evaluation of each area in §2.1 with a pass/finding/concern per item.
2. **Findings list** — each finding includes:
   - Unique finding ID (e.g. `AUDIT-CR-001`)
   - Severity: **Critical** / **High** / **Medium** / **Low** / **Informational**
   - Affected component and code reference
   - Proof-of-concept or reproduction steps (where applicable)
   - Recommended remediation
3. **Remediation plan** — agreed timeline for addressing findings per the severity ladder in §4.
4. **Re-test report** — after remediation, the firm re-tests each Critical/High finding and confirms resolution.

The report is delivered as a PDF together with a machine-readable findings summary
(JSON or CSV) for import into `bots/queue.yaml` as `kind: p2p_audit_finding` entries.

---

## 4. Findings Management

### 4.1 Severity ladder

| Severity | Definition | Remediation deadline |
|---|---|---|
| **Critical** | Breaks confidentiality, integrity, or authenticity of any game session; enables impersonation or key theft. | Before GA; no exceptions. |
| **High** | Requires an active attacker but allows meaningful degradation of security guarantees. | Before GA; re-tested by auditor. |
| **Medium** | Requires non-trivial conditions; defence-in-depth gap. | Queue entry with deadline ≤ 90 d post-GA. |
| **Low** | Best-practice deviation without exploitable consequence. | Documented; addressed in next scheduled maintenance. |
| **Informational** | Observation with no exploitable consequence. | Documented; no action required. |

### 4.2 Queue-entry format for audit findings

Every **Critical** and **High** finding is imported as a `kind: p2p_audit_finding`
queue entry in `bots/queue.yaml` immediately after the draft report is received.
Every **Medium** finding is added with `severity: med` and a `deadline` field.

```yaml
- id: audit-cr-001-<slug>
  mod: shared
  status: pending
  kind: p2p_audit_finding
  phase: security
  severity: critical        # critical | high | med | low | info
  audit_id: AUDIT-CR-001
  audit_report: bots/reports/p2p/audit-<yyyy>.pdf
  evidence:
    finding_id: AUDIT-CR-001
    component: p2p/protocol
    description: "<one-line description>"
  notes: "<remediation approach>"
  deadline: "<YYYY-MM-DD for medium; blank for critical/high (pre-GA)>"
```

### 4.3 Closure criteria

A Critical or High finding is **closed** when:
1. The fix is committed to `main` with a conventional commit message referencing the finding ID.
2. A regression test is added in the same commit (per the tests-with-code rule).
3. The audit firm's re-test confirms the finding is resolved.
4. The queue entry `status` is updated to `resolved`.

---

## 5. Quality Commitments

### 5.1 Performance

The audit engagement runs in **parallel** with the Phase 6 beta period and does not
block any other phase. Beta launch proceeds independently; only the GA-rollout gate
(§6.4) is held until Phase 15 is complete.

### 5.2 Efficiency

All findings from the audit are tracked as `kind: p2p_audit_finding` queue entries
with explicit proof-test references (see §4.2). This ensures mechanical prevention
of re-occurrence: the proof test for each finding remains in the test suite
permanently.

### 5.3 Stability

Every remediation commit **must** include a regression test per AGENTS.md §3
(tests-with-code rule). Remediations that change cryptographic code paths require
a re-run of the full P2P test suite before staging.

### 5.4 Reliability

The audit report is **reproducibly verifiable** against the audited commit SHA. The
`verify-reproducible-build.sh` script at the repo root (or the equivalent CI job)
is run against the audited SHA before the report is accepted. The audited SHA is
recorded in the `## 1. Engagement Overview` section of this document once the
engagement is commissioned.

### 5.5 Integrity

The audit firm is engaged for its time and expertise. A "zero findings" outcome is
acceptable, publishable, and does not affect the firm's compensation. This is
disclosed in the engagement contract to prevent any incentive to suppress findings.

---

## 6. Public Disclosure

After remediation and with the operator's permission, a **public summary** of the
audit results is published in [docs/p2p/P2P_AUDIT_HISTORY.md](P2P_AUDIT_HISTORY.md).

The summary includes:
- Audit date range and audited commit SHA.
- Name of the audit firm (if they consent to attribution).
- Total finding counts by severity.
- High-level description of any Critical/High findings and their resolution.
- Statement on Informational findings.

---

*This document is version-controlled. Last updated: 2026-05-20.*
