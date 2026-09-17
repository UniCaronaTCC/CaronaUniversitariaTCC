BEGIN;

-- Cria um campus principal para cada instituição.
INSERT INTO unicarona.instituicoes_campi (
  id_instituicao,
  nome,
  municipio,
  uf,
  ativo
)
SELECT
  id_instituicao,
  municipio,
  municipio,
  uf,
  TRUE
FROM unicarona.instituicoes
ON CONFLICT (
  id_instituicao,
  nome,
  municipio,
  uf
) DO NOTHING;

-- Adiciona e atualiza os campi de Araçatuba.
INSERT INTO unicarona.instituicoes_campi (
  id_instituicao,
  nome,
  municipio,
  uf,
  latitude,
  longitude,
  ativo
)
SELECT
  instituicao.id_instituicao,
  campus.nome,
  'Araçatuba',
  'SP',
  campus.latitude,
  campus.longitude,
  TRUE
FROM unicarona.instituicoes AS instituicao
INNER JOIN (
  VALUES
    (4522, 'Araçatuba', -21.23527500, -50.40606260),
    (322, 'Araçatuba I', -21.22306110, -50.42510770),
    (322, 'Araçatuba II', -21.20735590, -50.45062460),
    (56, 'Araçatuba - Odontologia', -21.20882780, -50.42878950),
    (56, 'Araçatuba - Veterinária', -21.18385920, -50.43700750)
) AS campus (
  codigo_emec,
  nome,
  latitude,
  longitude
)
  ON campus.codigo_emec = instituicao.codigo_emec
ON CONFLICT (
  id_instituicao,
  nome,
  municipio,
  uf
)
DO UPDATE SET
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  ativo = TRUE;

COMMIT;