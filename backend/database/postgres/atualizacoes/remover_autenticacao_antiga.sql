BEGIN;

ALTER TABLE unicarona.usuarios
  DROP COLUMN IF EXISTS senha,
  DROP COLUMN IF EXISTS email_verificado,
  DROP COLUMN IF EXISTS codigo_verificacao_email,
  DROP COLUMN IF EXISTS codigo_verificacao_email_expira_em,
  DROP COLUMN IF EXISTS codigo_verificacao_email_enviado_em,
  DROP COLUMN IF EXISTS codigo_redefinicao_senha,
  DROP COLUMN IF EXISTS codigo_redefinicao_senha_expira_em,
  DROP COLUMN IF EXISTS codigo_redefinicao_senha_enviado_em;

COMMIT;
