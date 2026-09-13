BEGIN;

CREATE TABLE IF NOT EXISTS unicarona.posicao_atual_carona (
  id_carona INTEGER PRIMARY KEY,
  latitude NUMERIC(10, 8) NOT NULL,
  longitude NUMERIC(11, 8) NOT NULL,
  direcao NUMERIC(6, 2),
  precisao NUMERIC(8, 2) NOT NULL,
  atualizado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_posicao_atual_carona
    FOREIGN KEY (id_carona)
    REFERENCES unicarona.caronas(id_carona)
    ON DELETE CASCADE,
  CONSTRAINT chk_posicao_atual_latitude
    CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_posicao_atual_longitude
    CHECK (longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_posicao_atual_direcao
    CHECK (direcao IS NULL OR direcao BETWEEN 0 AND 360),
  CONSTRAINT chk_posicao_atual_precisao
    CHECK (precisao BETWEEN 0 AND 10000)
);

COMMIT;
