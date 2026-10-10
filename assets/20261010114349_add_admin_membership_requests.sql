/*
# Add secure admin membership requests

1. New table
- `store_admin_requests`: a signed-in user's request to join the store management team, with reason, status, reviewer, and timestamps.

2. Security
- A customer may submit and view only their own pending request.
- Only an existing admin may review requests and change their status.
- Submitting a request never grants admin access automatically.

3. Important notes
- The role in `store_profiles` remains the source of truth for permissions.
- Approval must be performed by an existing admin or a trusted operator; clients cannot self-promote.
- The migration is additive and safe to re-run.
*/

CREATE TABLE IF NOT EXISTS store_admin_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_name text NOT NULL,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS store_one_pending_admin_request
  ON store_admin_requests(user_id) WHERE status = 'pending';

ALTER TABLE store_admin_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customers read own admin requests" ON store_admin_requests;
CREATE POLICY "customers read own admin requests" ON store_admin_requests FOR SELECT TO authenticated USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "customers create own admin requests" ON store_admin_requests;
CREATE POLICY "customers create own admin requests" ON store_admin_requests FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND status = 'pending');
DROP POLICY IF EXISTS "admins update admin requests" ON store_admin_requests;
CREATE POLICY "admins update admin requests" ON store_admin_requests FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin')) WITH CHECK (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
DROP POLICY IF EXISTS "admins delete admin requests" ON store_admin_requests;
CREATE POLICY "admins delete admin requests" ON store_admin_requests FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin'));
