-- Table for storing email OTPs
CREATE TABLE IF NOT EXISTS email_otps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  otp text NOT NULL,
  expires_at timestamptz NOT NULL,
  used boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Optional: index for quick lookup
CREATE INDEX IF NOT EXISTS idx_email_otps_email ON email_otps (email);
