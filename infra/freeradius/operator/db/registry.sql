CREATE TABLE IF NOT EXISTS device (
    id           uuid        PRIMARY KEY,            -- the certificate CN
    user_ref     integer     NOT NULL,               -- authentik uidNumber (LDAP)
    cert_serial  text        NOT NULL,               -- normalised hex serial of the issued certificate
    description  text,
    created_at   timestamptz NOT NULL DEFAULT now(),
    revoked_at   timestamptz,
    last_seen_at timestamptz
);

-- Read-only: the user_ref of an active device whose CN and serial match, NULL otherwise.
CREATE OR REPLACE FUNCTION wifi_cert_check(p_id uuid, p_serial text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT user_ref FROM device
    WHERE id = p_id
      AND revoked_at IS NULL
      AND ltrim(cert_serial, '0') = ltrim(lower(regexp_replace(p_serial, '[^0-9a-fA-F]', '', 'g')), '0');
$$;

-- Called only after the whole decision (registry, LDAP, VLAN) is an accept.
CREATE OR REPLACE FUNCTION wifi_cert_seen(p_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    UPDATE device SET last_seen_at = now() WHERE id = p_id AND revoked_at IS NULL;
$$;

REVOKE ALL ON DATABASE wifi FROM PUBLIC;
GRANT CONNECT ON DATABASE wifi TO wifi_radius;
REVOKE ALL ON FUNCTION wifi_cert_check(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION wifi_cert_check(uuid, text) TO wifi_radius;
REVOKE ALL ON FUNCTION wifi_cert_seen(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION wifi_cert_seen(uuid) TO wifi_radius;
