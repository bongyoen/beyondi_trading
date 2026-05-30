CREATE TABLE IF NOT EXISTS kis_auth (
  user_id TEXT PRIMARY KEY,
  app_key TEXT NOT NULL,
  app_secret TEXT NOT NULL,
  access_token TEXT,
  token_expiry TEXT,
  is_paper INTEGER NOT NULL DEFAULT 1,
  connected_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_kis_auth_user ON kis_auth(user_id);
