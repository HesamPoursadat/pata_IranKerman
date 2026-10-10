/*
# Add secure admin membership approval

1. New function
- `approve_store_admin_request`: lets an existing admin approve or reject a request and promotes the requested account only when approved.

2. Security
- The function derives the reviewer from `auth.uid()` and verifies that account is already an admin.
- Anonymous callers cannot execute it.
- The requested role is never accepted from the browser; approval sets it server-side.

3. Important notes
- The function uses a fixed public search path and validates the request status before changing it.
- This is additive and safe to re-run.
*/

CREATE OR REPLACE FUNCTION approve_store_admin_request(p_request_id uuid, p_approve boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM store_profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  SELECT user_id INTO v_user_id
  FROM store_admin_requests
  WHERE id = p_request_id AND status = 'pending'
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Request is no longer pending';
  END IF;

  UPDATE store_admin_requests
  SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
      reviewed_by = auth.uid(),
      reviewed_at = now()
  WHERE id = p_request_id;

  IF p_approve THEN
    UPDATE store_profiles SET role = 'admin' WHERE id = v_user_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION approve_store_admin_request(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION approve_store_admin_request(uuid, boolean) TO authenticated;
