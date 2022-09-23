-- This cant be done in a transaction
ALTER SYSTEM SET anon.masking_policies = 'anon, rgpd';

BEGIN;

CREATE EXTENSION anon CASCADE;

-- ALTER SYSTEM requires to restart the instance for the change to take effect
-- So we force the registration
SELECT anon.register_masking_policy('gdpr');

SELECT COUNT(*)=2 FROM pg_seclabels WHERE provider='gdpr';

CREATE ROLE zoe;
SECURITY LABEL FOR gdpr ON ROLE zoe IS 'MASKED';

SELECT COUNT(*)=3 FROM pg_seclabels WHERE provider='gdpr';

SELECT anon.register_masking_policy('foo; CREATE ROLE alex SUPERUSER LOGIN;');

ROLLBACK;

ALTER SYSTEM RESET anon.masking_policies;
