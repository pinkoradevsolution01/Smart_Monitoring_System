-- Activation Code Requests Table
-- This table stores customer requests for activation codes
-- Developer can view and fulfill these requests from the dashboard

CREATE TABLE IF NOT EXISTS activation_code_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_name TEXT NOT NULL,
    package_price TEXT NOT NULL,
    request_type TEXT NOT NULL, -- 'monthly', 'trial_upgrade'
    business_name TEXT NOT NULL,
    contact_email TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    additional_notes TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'fulfilled', 'cancelled'
    activation_code TEXT, -- Filled when fulfilled
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    fulfilled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_code_requests_status ON activation_code_requests(status);
CREATE INDEX IF NOT EXISTS idx_code_requests_email ON activation_code_requests(contact_email);
CREATE INDEX IF NOT EXISTS idx_code_requests_requested_at ON activation_code_requests(requested_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE activation_code_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert (submit requests)
CREATE POLICY "Anyone can submit code requests"
ON activation_code_requests
FOR INSERT
TO public
WITH CHECK (true);

-- Policy: Anyone can read their own requests by email
CREATE POLICY "Users can view their own requests"
ON activation_code_requests
FOR SELECT
TO public
USING (true); -- For now, allow all reads (developer needs to see all)

-- Policy: Only authenticated users can update (for developers)
CREATE POLICY "Authenticated users can update requests"
ON activation_code_requests
FOR UPDATE
TO authenticated
USING (true);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_code_requests_updated_at
    BEFORE UPDATE ON activation_code_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sample query to view pending requests (for developer dashboard)
-- SELECT * FROM activation_code_requests WHERE status = 'pending' ORDER BY requested_at DESC;
