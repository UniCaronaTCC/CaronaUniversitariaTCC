BEGIN;
ALTER TABLE unicarona.pontos_embarque
  ADD COLUMN IF NOT EXISTS percorrido_em TIMESTAMPTZ;
COMMIT;
