# P2P Security Audit History

> **Roadmap reference:** [docs/p2p/P2P_ROADMAP.md](P2P_ROADMAP.md) § Phase 15.1.4  
> **Engagement scope:** [docs/p2p/P2P_AUDIT_SCOPE.md](P2P_AUDIT_SCOPE.md)

This file is the **public record** of external security audits performed on the
Chess Recast P2P protocol and application. An entry is added here after each
audit concludes and remediation is complete, with the operator's permission.

Publishing this record builds user trust and is standard practice for
security-conscious open-source projects. The audit firm is credited only if they
consent to attribution.

---

## How Entries Are Added

After an audit engagement concludes:

1. All Critical/High findings must be remediated and re-tested (per
   [docs/p2p/P2P_AUDIT_SCOPE.md](P2P_AUDIT_SCOPE.md) §4).
2. The operator prepares a **public summary** (see template below).
3. The summary is committed to this file in a conventional commit:
   `docs(security): publish audit summary <yyyy-audit-N> [run_id]`.
4. A link to the full report (or its hash if not published) is referenced.

---

## Audit Log

*No audits have been conducted yet. This file will be updated when the first
engagement is commissioned and completed.*

---

## Entry Template

Use this template for each audit entry:

```markdown
### Audit <yyyy>-<N>: <Audit Firm Name (if attributed)>

| Field              | Value |
|--------------------|-------|
| **Audit date**     | YYYY-MM-DD – YYYY-MM-DD |
| **Audited SHA**    | `<git commit sha>` |
| **Scope**          | Cryptographic protocol audit / Application penetration test |
| **Firm**           | <Name or "Anonymous"> |
| **Report hash**    | SHA-256: `<hash of full report PDF>` |

#### Finding summary

| Severity     | Count | Remediated before publication |
|--------------|-------|-------------------------------|
| Critical     | N     | Yes / N/A                     |
| High         | N     | Yes / N/A                     |
| Medium       | N     | N in queue, N resolved        |
| Low          | N     | Documented                    |
| Informational| N     | Documented                    |

#### Notable findings (high-level, no exploit details)

- **AUDIT-<N>-001** (Critical/High): <one-line description of the issue>. Resolved in commit `<sha>` with regression test `<test path>`.
- (additional entries as needed)

#### Statement

> All Critical and High findings identified in this audit have been remediated
> and verified by re-test before this summary was published. Medium findings
> are tracked as `kind: p2p_audit_finding` queue entries with explicit deadlines.
> Low and Informational findings are documented in the private report.
```

---

*This document is version-controlled. Last updated: 2026-05-20.*
