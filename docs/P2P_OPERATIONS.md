# P2P Operations Runbook

This document covers the per-CVE severity playbook, forced-update procedure,
and the key-rotation calendar required by §3.10 and §3.11 of the P2P Roadmap.

## CVE Severity Playbook (§3.10)

When the CVE-watcher surfaces a new advisory, the on-call operator follows this
playbook based on the CVSS severity tier:

| Severity | SLA   | Required action                                                                 |
|----------|-------|---------------------------------------------------------------------------------|
| Critical | 7 d   | Ship a patched build immediately. Set `min_client_version` on the signaling server to the patched version. Clients below the floor receive `CVE_REQUIRES_FORCED_UPDATE` (HTTP 426) with a deep-link to the store update page. File a `kind: p2p_cve / severity: critical` entry in `agent/queue.yaml`. |
| High     | 30 d  | Ship a patched build within the window. Set `min_client_version` when patch lands. Notify users via in-app banner. |
| Medium   | 90 d  | Include fix in the next regular release. No forced update unless CVSS vectors indicate exploitability in the P2P threat model. |
| Low      | next release | Bundle fix in next maintenance release. No forced update. |

### Forced-update procedure

1. Identify the CVE advisory in `signaling/internal/cve/queue.json`.
2. Build and release the patched version to the app stores.
3. Once store review passes, run:

   ```bash
   # Update the server floor — all clients below this version receive HTTP 426.
   export MIN_CLIENT_VERSION=<patched-version>
   # Restart the signaling server with the updated environment variable.
   # See deploy/main.tf for Terraform variable: signaling_min_client_version.
   ```

4. Mark the CVE entry as patched in `queue.json`:

   ```bash
   # Use the CVE queue CLI (when cve_watcher is wired) or edit queue.json by hand.
   jq 'map(if .id == "<CVE-ID>" then .patched_at = (now | todate) else . end)' \
     signaling/internal/cve/queue.json > /tmp/q.json && mv /tmp/q.json signaling/internal/cve/queue.json
   ```

5. Verify the SLA-panel test passes: `go test ./internal/cve/... -run TestSLA`.
6. Update this runbook and the `docs/P2P_SIGNALING_RUNBOOK.md` with the incident timeline.

---

## Key-Rotation Calendar (§3.11)

This section documents the expected rotation schedule for all secrets used by
the signaling server and the P2P session layer.

| Key | Rotation interval | Who rotates | SLA for overdue rotation |
|-----|-------------------|-------------|--------------------------|
| TURN HMAC signing key | Quarterly (every 90 d) | Automated job (§3.11) | `KEY_ROTATION_OVERDUE` alert → PagerDuty |
| Push-token encryption key | Per device-key rotation + at most 30 d TTL; server evicts stale tokens > 90 d | Client-driven re-registration | Stale-token GC job in `store.PurgeExpired` |
| Signed-config signing key (Ed25519) | Annually | Operator (via KMS) | `KEY_ROTATION_OVERDUE` alert if > 365 d since last rotation |
| KMS / install-seal key (AEAD) | Biennially (every 2 y) or on confirmed leak | Operator (via cloud KMS) | Immediate if leaked; biennial otherwise |

### TURN HMAC rotation procedure

1. Generate a new HMAC key:

   ```bash
   openssl rand -base64 32
   ```

2. Set the new key as `TURN_HMAC_KEY_CURRENT` in the signaling server config and
   move the old value to `TURN_HMAC_KEY_PREVIOUS`. Both keys must be live
   simultaneously for the duration of the previous TURN session lifetime (1 h).
3. After 1 h has elapsed, clear `TURN_HMAC_KEY_PREVIOUS`.
4. Update `KEY_LAST_ROTATED_AT` in the operator dashboard config to suppress the
   overdue alert.

### Signed-config signing key rotation procedure

1. Generate a new Ed25519 key pair via the KMS.
2. Add the new public key to the client trust set (shipped in the next app build).
3. Wait one full app-update cycle (approx. 2 weeks post-release, when > 95% of
   active users are on the new build).
4. Retire the old public key from the trust set in the subsequent app build.
5. The signaling server may now sign configs exclusively with the new key.

### KMS / install-seal key rotation procedure

Invoke on biennial schedule or immediately on confirmed key leak:

1. Re-encrypt all at-rest data with the new key (rolling migration in the
   litestream replica layer).
2. Burn the old key in the KMS after migration completes.
3. Update the Terraform `kms_key_arn` variable and roll the signaling server.
4. Run the cold-restore drill (`signaling/test/dr/cold_restore_drill_test.go`) to
   confirm the new key decrypts the latest snapshot.
