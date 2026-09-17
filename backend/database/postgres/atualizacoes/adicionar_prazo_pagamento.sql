-- Executar manualmente na conexao PostgreSQL do projeto.
-- Adiciona o prazo de pagamento sem expirar solicitacoes nesta etapa.
BEGIN;

ALTER TABLE unicarona.solicitacoes
  ADD COLUMN IF NOT EXISTS pagamento_limite_em TIMESTAMPTZ;

-- Concede prazo aos aceites antigos que ainda comportam pagamento.
UPDATE unicarona.solicitacoes AS solicitacao
SET pagamento_limite_em = LEAST(
  CURRENT_TIMESTAMP + INTERVAL '1 hour',
  (
    (carona.data_inicio + carona.horario)
      AT TIME ZONE 'America/Sao_Paulo'
  ) - INTERVAL '15 minutes'
)
FROM unicarona.caronas AS carona
WHERE solicitacao.id_carona = carona.id_carona
  AND solicitacao.status = 'ACEITA'
  AND solicitacao.pagamento_limite_em IS NULL
  AND carona.recorrente = FALSE
  AND (
    (carona.data_inicio + carona.horario)
      AT TIME ZONE 'America/Sao_Paulo'
  ) - INTERVAL '15 minutes' > CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_solicitacoes_pagamento_limite
  ON unicarona.solicitacoes (pagamento_limite_em)
  WHERE status = 'ACEITA' AND pagamento_limite_em IS NOT NULL;

COMMIT;
