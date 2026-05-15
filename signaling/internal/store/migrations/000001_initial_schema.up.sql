-- 000001_initial_schema.up.sql
-- Initial signaling server schema.
-- All fields conform to the PII minimisation policy:
--   account_pub (pubkey, not personal data), ip_coarse (/24 IPv4 / /48 IPv6),
--   wrapped_blob (encrypted, opaque), token_enc (encrypted push token).
-- Forbidden columns: email, name, full_ip, phone, dob, raw_push_token.

CREATE TABLE IF NOT EXISTS accounts (
    account_pub   TEXT PRIMARY KEY,
    device_pub    TEXT NOT NULL,
    last_seen_ts  INTEGER NOT NULL,
    ip_coarse     TEXT    NOT NULL DEFAULT '',
    wrapped_blob  BLOB
);

CREATE TABLE IF NOT EXISTS offers (
    id            TEXT PRIMARY KEY,
    sender_pub    TEXT NOT NULL,
    recipient_pub TEXT NOT NULL,
    sdp_payload   TEXT NOT NULL,
    created_at    INTEGER NOT NULL,
    expires_at    INTEGER NOT NULL  -- TTL: 5 min from created_at
);

CREATE TABLE IF NOT EXISTS ice_candidates (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT    NOT NULL,
    candidate  TEXT    NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS push_tokens (
    device_pub   TEXT PRIMARY KEY,
    token_enc    BLOB    NOT NULL,   -- Encrypted at rest; raw push tokens NEVER stored
    provider     TEXT    NOT NULL,
    last_seen_ts INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS rebind_audit (
    account_pub TEXT    NOT NULL,
    event_ts    INTEGER NOT NULL,
    event_type  TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
