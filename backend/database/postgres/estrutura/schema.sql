BEGIN;

CREATE SCHEMA IF NOT EXISTS unicarona;

-- O frontend e os usuários da Data API não acessam este esquema.
REVOKE ALL ON SCHEMA unicarona FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA unicarona
  REVOKE ALL ON TABLES FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA unicarona
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;

COMMIT;