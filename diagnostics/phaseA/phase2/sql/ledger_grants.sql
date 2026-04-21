-- Append-only ledger grants for compliance_ledger.events
-- Replace :app_role and :app_role_password before execution in manual workflows.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = ':app_role') THEN
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', ':app_role', ':app_role_password');
    ELSE
        EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', ':app_role', ':app_role_password');
    END IF;
END
$$;

GRANT USAGE ON SCHEMA masstransit TO :app_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA masstransit TO :app_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA masstransit TO :app_role;

GRANT USAGE ON SCHEMA compliance_ledger TO :app_role;
GRANT SELECT, INSERT ON TABLE compliance_ledger.events TO :app_role;
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE compliance_ledger.events FROM :app_role;
