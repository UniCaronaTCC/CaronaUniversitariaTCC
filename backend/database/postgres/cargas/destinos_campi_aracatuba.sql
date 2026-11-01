-- Requer 20261101202707_adicionar_metadados_destinos_campi.sql.
-- Fontes e limites em ../atualizacoes/destinos-campi-aracatuba.md.
-- Oito unidades existentes; nao cria, renomeia, desativa ou funde campi.
BEGIN;

SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';

CREATE TEMP TABLE destinos_campi_aracatuba_aprovados (
  codigo_emec INTEGER NOT NULL,
  nome_campus VARCHAR(150) NOT NULL,
  rotulo_unidade VARCHAR(150) NOT NULL,
  endereco_completo VARCHAR(500) NOT NULL,
  latitude NUMERIC(10,8),
  longitude NUMERIC(11,8),
  PRIMARY KEY (codigo_emec, nome_campus)
) ON COMMIT DROP;

INSERT INTO destinos_campi_aracatuba_aprovados VALUES
  (4522, 'Araçatuba', 'Araçatuba - Jardim Alvorada',
    'Rodovia Senador Teotônio Vilela, 3821 - Jardim Alvorada - CEP 16016-500', NULL, NULL),
  (322, 'Araçatuba I', 'Campus Baguaçu - Araçatuba I',
    'Avenida Baguaçu, 1939 - Jardim Alvorada - CEP 16018-555', NULL, NULL),
  (322, 'Araçatuba II', 'Polo Planalto - Araçatuba II',
    'Rua Porangaba, 976 - Planalto - CEP 16072-475', NULL, NULL),
  (56, 'Araçatuba - Odontologia', 'Odontologia - José Bonifácio',
    'Rua José Bonifácio, 1193 - Vila Mendonça - CEP 16015-050', NULL, NULL),
  (56, 'Araçatuba - Veterinária', 'Medicina Veterinária - Clóvis Pestana',
    'Rua Clóvis Pestana, 793 - Dona Amélia - CEP 16050-680', NULL, NULL),
  (845, 'Araçatuba', 'Maurício de Nassau',
    'Rua Maurício de Nassau, 1191 - Santana - CEP 16050-480', NULL, NULL),
  (1418, 'Araçatuba', 'Jardim Sumaré',
    'Rua Antônio Afonso de Toledo, 595 - Jardim Sumaré - CEP 16015-270', -21.21307520, -50.43053199),
  (15697, 'Araçatuba', 'Prof. Fernando Amaral de Almeida Prado',
    'Avenida Prestes Maia, 1764 - Jardim Ipanema - CEP 16052-045', NULL, NULL);

-- Mantem a validacao e a atualizacao sob o mesmo bloqueio, sem alterar ACL/RLS.
LOCK TABLE unicarona.instituicoes, unicarona.instituicoes_campi
  IN SHARE ROW EXCLUSIVE MODE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM destinos_campi_aracatuba_aprovados d
    LEFT JOIN unicarona.instituicoes i
      ON i.codigo_emec = d.codigo_emec AND i.ativa
    LEFT JOIN unicarona.instituicoes_campi c
      ON c.id_instituicao = i.id_instituicao AND c.nome = d.nome_campus
      AND c.municipio = 'Araçatuba' AND c.uf = 'SP' AND c.ativo
    GROUP BY d.codigo_emec, d.nome_campus
    HAVING COUNT(c.id_campus) <> 1
  ) THEN
    RAISE EXCEPTION 'Carga de destinos cancelada: campus ausente, inativo ou ambiguo. Conferir eMEC, nome e cidade.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM destinos_campi_aracatuba_aprovados d
    JOIN unicarona.instituicoes i ON i.codigo_emec = d.codigo_emec
    JOIN unicarona.instituicoes_campi c
      ON c.id_instituicao = i.id_instituicao AND c.nome = d.nome_campus
      AND c.municipio = 'Araçatuba' AND c.uf = 'SP'
    WHERE (NULLIF(BTRIM(c.rotulo_unidade), '') IS NOT NULL
      AND BTRIM(c.rotulo_unidade) IS DISTINCT FROM d.rotulo_unidade)
      OR (NULLIF(BTRIM(c.endereco_completo), '') IS NOT NULL
      AND BTRIM(c.endereco_completo) IS DISTINCT FROM d.endereco_completo)
  ) THEN
    RAISE EXCEPTION 'Carga de destinos cancelada: existem metadados diferentes. Revisar sem sobrescrever alteracoes anteriores.';
  END IF;
END;
$$;

UPDATE unicarona.instituicoes_campi c
SET rotulo_unidade = d.rotulo_unidade,
    endereco_completo = d.endereco_completo,
    latitude = CASE WHEN c.latitude IS NULL AND c.longitude IS NULL
      THEN d.latitude ELSE c.latitude END,
    longitude = CASE WHEN c.latitude IS NULL AND c.longitude IS NULL
      THEN d.longitude ELSE c.longitude END
FROM destinos_campi_aracatuba_aprovados d
JOIN unicarona.instituicoes i ON i.codigo_emec = d.codigo_emec
WHERE c.id_instituicao = i.id_instituicao AND c.nome = d.nome_campus
  AND c.municipio = 'Araçatuba' AND c.uf = 'SP' AND c.ativo
  AND (c.rotulo_unidade IS DISTINCT FROM d.rotulo_unidade
    OR c.endereco_completo IS DISTINCT FROM d.endereco_completo
    OR (c.latitude IS NULL AND c.longitude IS NULL AND d.latitude IS NOT NULL));

COMMIT;
