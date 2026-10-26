-- Entry-only device grants. No Firebase credential or raw grant is persisted.
-- Account rewards still require the existing authenticated player API.
CREATE TABLE IF NOT EXISTS player_native_entry_grants (
  code_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  receipt_id TEXT NOT NULL,
  challenge TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  consumed_at INTEGER,
  FOREIGN KEY (receipt_id) REFERENCES player_opening_recovery_receipts(receipt_id)
);
CREATE INDEX IF NOT EXISTS native_entry_user_created
  ON player_native_entry_grants(user_id, created_at);
