# Chess Recast — Bug Bounty Program Policy

> **Roadmap reference:** [docs/P2P_ROADMAP.md](P2P_ROADMAP.md) § Phase 15.3  
> **Security disclosure file:** `frontend/web/.well-known/security.txt` (RFC 9116)  
> **Related:** [docs/P2P_AUDIT_SCOPE.md](P2P_AUDIT_SCOPE.md), [docs/P2P_AUDIT_HISTORY.md](P2P_AUDIT_HISTORY.md)

This document defines the Chess Recast bug bounty program: what is in scope,
how to report, how findings are assessed and rewarded, and how the project
handles coordinated disclosure.

---

## 1. Scope

### 1.1 In Scope

| Target | Details |
|--------|---------|
| **Signaling server** | Authentication, authorisation, session handling, TURN credential issuance, WebSocket message handling. |
| **P2P protocol** | Cryptographic handshake, key exchange, identity binding, replay-attack resistance, downgrade resistance as specified in [docs/P2P_PROTOCOL.md](P2P_PROTOCOL.md). |
| **Client cryptography / identity** | Secure storage on iOS and Android, key-derivation correctness, identity-key ceremonies. |
| **DataChannel security** | DTLS configuration, ciphertext integrity, forward-secrecy guarantees. |
| **Reproducible-build pipeline** | Verification that published binaries match the audited commit SHA. |

### 1.2 Out of Scope

The following are explicitly **out of scope**:

- Social engineering of team members or users.
- Physical attacks or device seizure.
- Denial-of-service attacks that exploit legitimate protocol features (e.g.
  opening many connections) rather than implementation flaws.
- Vulnerabilities in upstream dependencies that have already been publicly
  disclosed and are pending an upstream fix.
- Bugs with no realistic security impact (UI glitches, typos, non-security
  performance issues).
- Chess engine logic (e.g. move-quality blunders) — these are not security
  vulnerabilities.

### 1.3 Safe Harbour

Researchers who follow this policy and act in good faith will not face legal
action related to their research. Testing must remain non-destructive:

- Do not access, alter, or delete other users' data.
- Do not disrupt the production signaling service for legitimate users.
- Use dedicated test accounts for all active testing.

---

## 2. Triage SLA

| Milestone | Target |
|-----------|--------|
| **Acknowledgement** | Within **5 business days** of receiving the report. |
| **Initial assessment** (severity + validity) | Within **14 business days** of receiving the report. |
| **Critical finding remediation** | Within **7 days** of assessment confirmation. |
| **High finding remediation** | Within **30 days** of assessment confirmation. |
| **Medium finding remediation** | Within **90 days** of assessment confirmation. |
| **Low / Informational** | Documented and addressed at the project's discretion. |

Severity follows the same ladder defined in
[docs/P2P_AUDIT_SCOPE.md](P2P_AUDIT_SCOPE.md) §4.1.

---

## 3. Hall of Fame

Researchers who responsibly disclose valid security vulnerabilities are publicly
credited here with their consent. We do not pay monetary bounties at this stage;
credit and a thank-you letter are the current rewards.

| Researcher | Reported | Severity | Description |
|------------|----------|----------|-------------|
| *(hall of fame is empty — no reports received yet)* | | | |

To be listed, indicate your preferred attribution in your initial report.

---

## 4. Coordinated Disclosure

### 4.1 Standard window

The project follows a **90-day coordinated disclosure** window. After the
window expires, or after a patch has been released (whichever comes first), the
researcher may publish their findings.

The project will make every effort to remediate and publish a security advisory
before the window expires. If this is not possible (e.g. due to upstream
dependency delays), we will request a short, documented extension with the
researcher's consent.

### 4.2 Embargoed CVE handling

If a finding qualifies for a CVE:

1. The project will request a CVE from MITRE or a CNA under embargo
   simultaneously with commencing remediation.
2. The CVE draft will be shared with the researcher for accuracy review before
   publication.
3. The CVE will be published on the same day the patch is released, alongside a
   security advisory in the repository.
4. If the embargo is broken unilaterally (e.g. by a third party), the project
   will accelerate patching and publish immediately.

### 4.3 How to Report

Send your report to the contact address in
`frontend/web/.well-known/security.txt`. Include:

- A description of the vulnerability.
- Steps to reproduce (a minimal proof-of-concept or a test case).
- The affected version(s) or commit SHA.
- Your assessment of impact / severity.
- Your preferred attribution (name, handle, or "anonymous").

Encrypt sensitive reports using the PGP key at
`https://chessrecast.example/.well-known/pgp-key.txt`.

---

*This document is version-controlled. Last updated: 2026-05-20.*
