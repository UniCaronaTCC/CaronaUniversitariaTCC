BEGIN;

-- Aplicar antes de iniciar a versão nova do backend (synchronize está desativado).
-- As caronas recorrentes antigas não são convertidas: o cadastro antigo não
-- identifica a data de cada reserva. Recrie a programação após revisar essas
-- reservas com o motorista. Este script não apaga caronas nem solicitações.

CREATE TABLE IF NOT EXISTS unicarona.recorrencias_carona (
  id_recorrencia SERIAL PRIMARY KEY,
  id_usuario INTEGER NOT NULL REFERENCES unicarona.usuarios(id_usuario),
  ativa BOOLEAN NOT NULL DEFAULT TRUE,
  origem VARCHAR(255) NOT NULL,
  origem_cidade VARCHAR(100),
  origem_latitude NUMERIC(10,8) NOT NULL CHECK (origem_latitude BETWEEN -90 AND 90),
  origem_longitude NUMERIC(11,8) NOT NULL CHECK (origem_longitude BETWEEN -180 AND 180),
  destino VARCHAR(255) NOT NULL,
  destino_cidade VARCHAR(100),
  destino_latitude NUMERIC(10,8) NOT NULL CHECK (destino_latitude BETWEEN -90 AND 90),
  destino_longitude NUMERIC(11,8) NOT NULL CHECK (destino_longitude BETWEEN -180 AND 180),
  data_inicio DATE NOT NULL,
  data_fim DATE CHECK (data_fim IS NULL OR data_fim >= data_inicio),
  horario TIME NOT NULL,
  dias_semana SMALLINT[] NOT NULL CHECK (
    cardinality(dias_semana) BETWEEN 1 AND 7
    AND dias_semana <@ ARRAY[1,2,3,4,5,6,7]::SMALLINT[]
    AND array_position(dias_semana, NULL) IS NULL
  ),
  vagas INTEGER NOT NULL CHECK (vagas BETWEEN 1 AND 4),
  valor NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
  observacoes TEXT,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_recorrencias_motorista
  ON unicarona.recorrencias_carona (id_usuario);

CREATE SEQUENCE IF NOT EXISTS unicarona.pontos_recorrencia_id_seq;
CREATE TABLE IF NOT EXISTS unicarona.pontos_embarque_recorrencia (
  id_ponto_embarque_recorrencia INTEGER PRIMARY KEY DEFAULT nextval('unicarona.pontos_recorrencia_id_seq'),
  id_recorrencia INTEGER NOT NULL REFERENCES unicarona.recorrencias_carona(id_recorrencia) ON DELETE CASCADE,
  nome VARCHAR(100),
  endereco VARCHAR(255) NOT NULL,
  latitude NUMERIC(10,8) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude NUMERIC(11,8) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  ordem INTEGER NOT NULL CHECK (ordem > 0),
  UNIQUE (id_recorrencia, ordem)
);
ALTER SEQUENCE unicarona.pontos_recorrencia_id_seq OWNED BY unicarona.pontos_embarque_recorrencia.id_ponto_embarque_recorrencia;

ALTER TABLE unicarona.caronas
  ADD COLUMN IF NOT EXISTS id_recorrencia INTEGER REFERENCES unicarona.recorrencias_carona(id_recorrencia),
  ADD COLUMN IF NOT EXISTS data_ocorrencia DATE;
-- A data original continua reservada mesmo se o motorista editar/cancelar o dia.
CREATE UNIQUE INDEX IF NOT EXISTS idx_carona_recorrencia_data
  ON unicarona.caronas (id_recorrencia, data_ocorrencia);

ALTER TABLE unicarona.recorrencias_carona ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON unicarona.recorrencias_carona FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE unicarona.recorrencias_carona_id_recorrencia_seq FROM PUBLIC, anon, authenticated;

ALTER TABLE unicarona.pontos_embarque_recorrencia ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON unicarona.pontos_embarque_recorrencia FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE unicarona.pontos_recorrencia_id_seq FROM PUBLIC, anon, authenticated;

COMMIT;
