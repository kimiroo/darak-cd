-- Idempotent: safe to run again. Bump the Job name in 03-wifi-schema-job.yaml
-- whenever this file changes (Jobs are immutable).

CREATE TABLE IF NOT EXISTS device (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL,                  -- authentik user uuid
    mac          macaddr     NOT NULL UNIQUE,           -- one device belongs to one user
    description  text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz,                           -- last attempt that passed authentik
    approved     boolean     NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS device_user_id_idx ON device (user_id);

-- Called by FreeRADIUS after authentik accepted the user.
-- Unknown MAC  -> registered as pending (approved = false), returns false.
-- Known MAC    -> returns approved for that user, false if it belongs to someone else.
-- To approve a device an admin sets approved = true.
CREATE OR REPLACE FUNCTION wifi_check(p_user uuid, p_mac macaddr)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_approved boolean;
BEGIN
    INSERT INTO device (user_id, mac) VALUES (p_user, p_mac)
        ON CONFLICT (mac) DO NOTHING;

    UPDATE device SET last_seen_at = now()
        WHERE mac = p_mac AND user_id = p_user
        RETURNING approved INTO v_approved;

    RETURN COALESCE(v_approved, false);
END;
$$;

REVOKE ALL ON DATABASE wifi FROM PUBLIC;
GRANT CONNECT ON DATABASE wifi TO wifi_radius;
REVOKE ALL ON FUNCTION wifi_check(uuid, macaddr) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION wifi_check(uuid, macaddr) TO wifi_radius;
