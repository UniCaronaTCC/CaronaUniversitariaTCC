USE carona_universitaria;

CREATE TABLE IF NOT EXISTS instituicoes_campi (
  id_campus INT AUTO_INCREMENT PRIMARY KEY,
  id_instituicao INT NOT NULL,
  nome VARCHAR(150) NOT NULL,
  municipio VARCHAR(100) NOT NULL,
  uf CHAR(2) NOT NULL,
  latitude DECIMAL(10, 8) NULL,
  longitude DECIMAL(11, 8) NULL,
  ativo BOOLEAN NOT NULL DEFAULT TRUE,

  UNIQUE KEY uq_campus_instituicao_municipio (
    id_instituicao,
    nome,
    municipio,
    uf
  ),

  CONSTRAINT fk_campi_instituicoes
    FOREIGN KEY (id_instituicao)
    REFERENCES instituicoes(id_instituicao)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Começa com a localização principal informada pelo MEC.
INSERT IGNORE INTO instituicoes_campi (
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
FROM instituicoes;

-- Campi de Araçatuba usados no início do projeto.
INSERT IGNORE INTO instituicoes_campi (
  id_instituicao,
  nome,
  municipio,
  uf,
  latitude,
  longitude,
  ativo
)
SELECT
  instituicoes.id_instituicao,
  campi.nome,
  'Araçatuba',
  'SP',
  campi.latitude,
  campi.longitude,
  TRUE
FROM instituicoes
INNER JOIN (
  SELECT
    4522 AS codigo_emec,
    'Araçatuba' AS nome,
    -21.23527500 AS latitude,
    -50.40606260 AS longitude
  UNION ALL
  SELECT 322, 'Araçatuba I', -21.22306110, -50.42510770
  UNION ALL
  SELECT 322, 'Araçatuba II', -21.20735590, -50.45062460
  UNION ALL
  SELECT 56, 'Araçatuba - Odontologia', -21.20882780, -50.42878950
  UNION ALL
  SELECT 56, 'Araçatuba - Veterinária', -21.18385920, -50.43700750
) AS campi ON campi.codigo_emec = instituicoes.codigo_emec;

-- Atualiza as coordenadas caso o script já tenha sido executado antes.
UPDATE instituicoes_campi
INNER JOIN instituicoes
  ON instituicoes.id_instituicao = instituicoes_campi.id_instituicao
INNER JOIN (
  SELECT
    4522 AS codigo_emec,
    'Araçatuba' AS nome,
    -21.23527500 AS latitude,
    -50.40606260 AS longitude
  UNION ALL
  SELECT 322, 'Araçatuba I', -21.22306110, -50.42510770
  UNION ALL
  SELECT 322, 'Araçatuba II', -21.20735590, -50.45062460
  UNION ALL
  SELECT 56, 'Araçatuba - Odontologia', -21.20882780, -50.42878950
  UNION ALL
  SELECT 56, 'Araçatuba - Veterinária', -21.18385920, -50.43700750
) AS campi
  ON campi.codigo_emec = instituicoes.codigo_emec
  AND campi.nome = instituicoes_campi.nome
SET
  instituicoes_campi.latitude = campi.latitude,
  instituicoes_campi.longitude = campi.longitude,
  instituicoes_campi.ativo = TRUE;

SELECT COUNT(*) AS total_campi FROM instituicoes_campi;

SELECT
  instituicoes.sigla,
  instituicoes.nome,
  instituicoes_campi.nome AS campus,
  instituicoes_campi.municipio,
  instituicoes_campi.uf
FROM instituicoes_campi
INNER JOIN instituicoes
  ON instituicoes.id_instituicao = instituicoes_campi.id_instituicao
WHERE instituicoes_campi.municipio = 'Araçatuba'
ORDER BY instituicoes.nome;
