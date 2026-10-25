-- Executar antes de publicar o backend que salva os dados opcionais da CNH.
BEGIN;

ALTER TABLE unicarona.usuarios
  ADD COLUMN IF NOT EXISTS cnh_nome VARCHAR(150),
  ADD COLUMN IF NOT EXISTS cnh_registro VARCHAR(11);

COMMENT ON COLUMN unicarona.usuarios.cnh_nome IS
  'Nome extraído por OCR, sem comprovação de identidade; não altera o perfil.';
COMMENT ON COLUMN unicarona.usuarios.cnh_registro IS
  'Número de registro extraído por OCR, sem consulta a órgão oficial.';

COMMIT;
