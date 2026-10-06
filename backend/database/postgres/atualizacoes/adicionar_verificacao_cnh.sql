-- Aplicar apenas em bancos que ainda não receberam a verificação de CNH.
-- O Supabase UniCarona-storage já recebeu essas colunas manualmente.
BEGIN;

ALTER TABLE unicarona.usuarios
  ADD COLUMN IF NOT EXISTS cpf VARCHAR(11),
  ADD COLUMN IF NOT EXISTS status_verificacao_cnh VARCHAR(20) NOT NULL DEFAULT 'NAO_ENVIADA',
  ADD COLUMN IF NOT EXISTS cnh_categoria VARCHAR(5),
  ADD COLUMN IF NOT EXISTS cnh_validade DATE,
  ADD COLUMN IF NOT EXISTS cnh_registro_final VARCHAR(4),
  ADD COLUMN IF NOT EXISTS cnh_verificada_em TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS privacidade_aceita_em TIMESTAMPTZ;

UPDATE unicarona.usuarios
SET status_verificacao_cnh = 'NAO_ENVIADA'
WHERE status_verificacao_cnh IS NULL;

ALTER TABLE unicarona.usuarios
  ALTER COLUMN status_verificacao_cnh SET DEFAULT 'NAO_ENVIADA',
  ALTER COLUMN status_verificacao_cnh SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'unicarona.usuarios'::regclass
      AND conname = 'chk_usuarios_cpf'
  ) THEN
    ALTER TABLE unicarona.usuarios
      ADD CONSTRAINT chk_usuarios_cpf
      CHECK (cpf IS NULL OR cpf ~ '^[0-9]{11}$');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'unicarona.usuarios'::regclass
      AND conname = 'chk_usuarios_cnh_registro_final'
  ) THEN
    ALTER TABLE unicarona.usuarios
      ADD CONSTRAINT chk_usuarios_cnh_registro_final
      CHECK (cnh_registro_final IS NULL OR cnh_registro_final ~ '^[0-9]{4}$');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'unicarona.usuarios'::regclass
      AND conname = 'chk_usuarios_status_verificacao_cnh'
  ) THEN
    ALTER TABLE unicarona.usuarios
      ADD CONSTRAINT chk_usuarios_status_verificacao_cnh
      CHECK (status_verificacao_cnh IN (
        'NAO_ENVIADA', 'EM_ANALISE', 'APROVADA', 'RECUSADA'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'unicarona.usuarios'::regclass
      AND conname = 'chk_usuarios_cnh_verificacao_coerente'
  ) THEN
    ALTER TABLE unicarona.usuarios
      ADD CONSTRAINT chk_usuarios_cnh_verificacao_coerente
      CHECK (
        status_verificacao_cnh <> 'APROVADA'
        OR (
          cpf IS NOT NULL
          AND cnh_categoria IS NOT NULL
          AND cnh_validade IS NOT NULL
          AND cnh_verificada_em IS NOT NULL
          AND privacidade_aceita_em IS NOT NULL
        )
      );
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_usuarios_cpf
  ON unicarona.usuarios (cpf)
  WHERE cpf IS NOT NULL;

COMMIT;
