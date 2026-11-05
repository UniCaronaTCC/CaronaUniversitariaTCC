BEGIN;
SET LOCAL lock_timeout = '5s';

ALTER TABLE unicarona.pontos_embarque
  ADD COLUMN IF NOT EXISTS sugerido_por_passageiro boolean NOT NULL DEFAULT false;

-- Recupera a origem dos pontos antigos quando ainda há evidência da sugestão.
UPDATE unicarona.pontos_embarque ponto
SET sugerido_por_passageiro = true
WHERE NOT ponto.sugerido_por_passageiro
  AND EXISTS (
    SELECT 1 FROM unicarona.solicitacoes solicitacao
    WHERE solicitacao.id_ponto_embarque = ponto.id_ponto_embarque
      AND solicitacao.tipo_ponto_embarque = 'NOVO_SOLICITADO'
  );

COMMIT;
