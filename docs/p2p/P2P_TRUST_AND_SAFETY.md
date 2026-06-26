# ChessRecast — Trust and Safety Policy

> **Document scope:** peer-to-peer multiplayer feature only.  
> **Status:** v1 — published with Phase 14 implementation.  
> **Companion:** [docs/p2p/P2P_ROADMAP.md](P2P_ROADMAP.md) §14, [docs/p2p/P2P_IDENTITY_POLICY.md](P2P_IDENTITY_POLICY.md).

---

## 1. Scope

ChessRecast is a peer-to-peer chess application. Because games are negotiated directly between devices (with only a signaling relay), the operator cannot proactively read, moderate, or filter game content in transit. This document describes the tools available to users and the operator's commitment to reviewing filed reports.

All enforcement is reactive: users must report; the operator acts on reports.

---

## 2. User tools

### 2.1 Block (§14.1)

- **Device block**: blocks the specific device fingerprint. The blocked peer cannot initiate a new match with you. Their chat is silently dropped (they see no notification).
- **Account block**: also blocks the account fingerprint, surviving the opponent's device replacement (rebind). Account blocks appear in Settings > Safety > Blocked accounts.
- **Mid-game block**: ends the current session immediately with reason `BYE { reason: user_blocked }`. The game transcript is saved locally.
- **Unblock**: available at any time from Settings > Safety > Blocked accounts.

### 2.2 Mute (§14.2)

- **In-game mute**: hides incoming chat without ending the session; the opponent is not notified.
- **New-contact default**: the first message from any fingerprint you have never played before is held in a "show chat?" prompt to reduce unsolicited contact.
- **Reversible**: mute can be undone mid-game.

### 2.3 Report (§14.3)

Reports are an explicit, consent-gated action:

1. Tap **≡ → Report opponent** during or immediately after a game.
2. Select a reason: *harassment*, *sexual content*, *threats*, *cheating suspicion*, or *other*.
3. Review the bundle that will be uploaded (signed transcript hash + encrypted chat history + opponent fingerprint).
4. Tap **Send** to submit.

**You can cancel at any step without submitting anything.**

The bundle is encrypted in transit and at rest using the operator's KMS key. Your raw fingerprint is stored separately and is only revealed to the operator if they decide to escalate (e.g. account ban or law-enforcement referral). The bundle is signed under the reported peer's device key, making the reported content non-repudiable.

Reports are **not** acknowledged to the reported peer (no retaliation signal).

### 2.4 Age gate (§14.4)

ChessRecast requires users to be **13 years or older** to create an account (COPPA). In EU/EEA jurisdictions where GDPR-K applies, the threshold may be **16 years** (detected from device locale, best-effort). Users who indicate they are under the threshold cannot access chat features or the spectator mode.

---

## 3. Operator action ladder

| Severity | Trigger | Action | Timeline |
|---|---|---|---|
| **Warning** | First confirmed minor violation | In-app warning message (future v2 feature) | 14 days to review |
| **Chat suspension** | Repeated minor violations or first moderate violation | Chat features disabled for the account | 7 days to review |
| **Account suspension** | Serious violation (threats, sexual content) | All P2P features disabled; recovery code still valid | 7 days to review |
| **Account ban** | Severe / repeated serious violations | Account and all associated device fingerprints banned; recovery code invalidated | Immediate |
| **Law-enforcement referral** | Credible threats of harm or CSAM | Escalated per applicable law | Immediate |

### 3.1 Review SLA

> **For a solo-operated deployment (the current model):**  
> Reports are reviewed **best-effort within 7 days**. This is honestly stated — there is no team; reviews happen around other work. If you have filed a report for an urgent matter (threat of harm, CSAM), include "URGENT" in the free-text field; these are triaged first.

### 3.2 Appeal path

If you believe your account was suspended or banned in error:

1. Contact the operator via the email address in `security.txt` (see Phase 15.3).
2. Include your account fingerprint (visible in Settings > Identity > My fingerprint) and the date of suspension.
3. The operator will review within 30 days.

There is no automated appeal flow in v1.

---

## 4. Report bundle retention

- Filed report bundles are retained for **90 days** from the filing date.
- Bundles not actioned within 90 days are automatically purged.
- Bundles linked to a confirmed ban are retained per applicable data-retention law (typically 6 months to 3 years depending on jurisdiction).
- You may request deletion of your own filed reports via the email contact (subject to legal-hold exceptions).

---

## 5. What the operator cannot do

- **Read game content in transit**: all game data is end-to-end encrypted between peers. The signaling server never sees move data.
- **Proactively detect harassment**: without access to message content, proactive detection is not possible. Users must report.
- **Guarantee response time** beyond the SLA stated above for solo operation.
- **Unilaterally revoke your cryptographic keys**: account ban invalidates the signaling-layer account but does not delete your local device key or recovery code (your data remains yours).

---

## 6. Age and child safety

- Users under 13 (or 16 in applicable EU/EEA jurisdictions) cannot access chat or spectator features.
- Any report bundle flagged with `minor_involved: true` (triggered automatically when the age-gate indicates a minor is a party) is placed at the top of the operator's review queue.
- ChessRecast does not collect or display personally identifiable information beyond the cryptographic device fingerprint, which is a hash of a public key.

---

## 7. Transparency and updates

This policy is versioned in the repository (`docs/p2p/P2P_TRUST_AND_SAFETY.md`). Material changes are noted in the release notes. The current version is v1, published with the Phase 14 implementation.
