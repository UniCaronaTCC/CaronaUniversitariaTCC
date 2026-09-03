-- Executar na conexao PostgreSQL do projeto, com o schema unicarona existente.
-- Guarda apenas a identidade dos eventos processados, sem payload ou dados pessoais.
BEGIN;

CREATE TABLE IF NOT EXISTS unicarona.pagamentos_eventos_webhook (
  id_evento VARCHAR(100) NOT NULL,
  id_pagamento INTEGER NOT NULL,
  tipo VARCHAR(50) NOT NULL,
  processado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pagamentos_eventos_webhook_pkey PRIMARY KEY (id_evento),
  CONSTRAINT fk_pagamentos_eventos_webhook_pagamento
    FOREIGN KEY (id_pagamento)
    REFERENCES unicarona.pagamentos(id_pagamento)
    ON DELETE RESTRICT,
  CONSTRAINT chk_pagamentos_eventos_webhook_id
    CHECK (LENGTH(BTRIM(id_evento)) BETWEEN 1 AND 100),
  CONSTRAINT chk_pagamentos_eventos_webhook_tipo
    CHECK (LENGTH(BTRIM(tipo)) BETWEEN 1 AND 50)
);

CREATE INDEX IF NOT EXISTS idx_pagamentos_eventos_webhook_pagamento
  ON unicarona.pagamentos_eventos_webhook (id_pagamento, processado_em);

ALTER TABLE unicarona.pagamentos_eventos_webhook ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON unicarona.pagamentos_eventos_webhook
  FROM PUBLIC, anon, authenticated;

COMMIT;
