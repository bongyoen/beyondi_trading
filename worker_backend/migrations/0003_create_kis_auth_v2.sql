-- 기존 kis_auth 테이블을 모의/실전 동시 지원으로 변경
DROP TABLE IF EXISTS kis_auth;

CREATE TABLE IF NOT EXISTS kis_auth (
  user_id TEXT NOT NULL,
  env_type TEXT NOT NULL CHECK(env_type IN ('mock', 'real')),
  app_key TEXT NOT NULL,
  app_secret TEXT NOT NULL,
  access_token TEXT,
  token_expiry TEXT,
  account_no TEXT,
  product_code TEXT,
  connected_at TEXT NOT NULL,
  PRIMARY KEY (user_id, env_type),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_kis_auth_user ON kis_auth(user_id);
