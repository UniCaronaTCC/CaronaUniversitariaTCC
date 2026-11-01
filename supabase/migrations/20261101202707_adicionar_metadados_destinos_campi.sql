-- Aplicar antes do backend que consulta os metadados dos destinos.
-- Nao renomeia campus nem altera coordenadas, perfis ou caronas.
BEGIN;

SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

ALTER TABLE unicarona.instituicoes_campi
  ADD COLUMN IF NOT EXISTS rotulo_unidade VARCHAR(150),
  ADD COLUMN IF NOT EXISTS endereco_completo VARCHAR(500);

COMMENT ON COLUMN unicarona.instituicoes_campi.rotulo_unidade IS
  'Identificacao visual opcional da unidade. Nao substitui o nome interno usado nos perfis.';
COMMENT ON COLUMN unicarona.instituicoes_campi.endereco_completo IS
  'Endereco institucional conferido. Nao comprova coordenada ou ponto de embarque.';

COMMIT;
