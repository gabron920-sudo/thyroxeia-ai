-- Create ai_usage table for tracking daily quotas per user
CREATE TABLE IF NOT EXISTS ai_usage (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  model       text NOT NULL DEFAULT 'gemini-1.5-flash',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Index for fast daily quota lookups
CREATE INDEX IF NOT EXISTS ai_usage_user_date_idx ON ai_usage(user_id, created_at);

-- Row Level Security: users can only see their own usage
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Users see own usage" ON ai_usage
  FOR SELECT USING (auth.uid() = user_id);

-- FIX: Only service role (Railway backend) can insert — not anon clients
DROP POLICY IF EXISTS "Service role insert" ON ai_usage;
CREATE POLICY "Service role only insert" ON ai_usage
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- Profiles table: ensure plan column exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS plan text DEFAULT 'free';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS paypal_order_id text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS plan_activated_at timestamptz;

-- FIX: Enable RLS on profiles (was missing — anyone with anon key could read all plans)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own profile" ON profiles;
CREATE POLICY "Users see own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own profile" ON profiles;
CREATE POLICY "Users update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Service role full access profiles" ON profiles;
CREATE POLICY "Service role full access profiles" ON profiles
  FOR ALL USING (auth.role() = 'service_role');

-- Shoutouts table for Elite users
CREATE TABLE IF NOT EXISTS shoutouts (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

ALTER TABLE shoutouts ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read shoutouts
DROP POLICY IF EXISTS "Anyone can read shoutouts" ON shoutouts;
CREATE POLICY "Authenticated users read shoutouts" ON shoutouts
  FOR SELECT USING (auth.role() = 'authenticated');

-- Service role inserts shoutouts
DROP POLICY IF EXISTS "Service role insert shoutouts" ON shoutouts;
CREATE POLICY "Service role insert shoutouts" ON shoutouts
  FOR INSERT WITH CHECK (auth.role() = 'service_role');

-- ── otp_codes table (stores server-generated OTPs securely) ────────────────────
CREATE TABLE IF NOT EXISTS otp_codes (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  email       text NOT NULL,
  otp_hash    text NOT NULL,
  expires_at  timestamptz NOT NULL,
  used        boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages OTPs" ON otp_codes;
CREATE POLICY "Service role manages OTPs" ON otp_codes
  FOR ALL USING (auth.role() = 'service_role');
