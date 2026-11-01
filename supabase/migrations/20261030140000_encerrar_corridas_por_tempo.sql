BEGIN;

ALTER TABLE unicarona.caronas
  ADD COLUMN IF NOT EXISTS iniciada_em TIMESTAMPTZ;

-- O banco registra o inicio real. Reenvios e edicoes nao reiniciam o prazo.
CREATE OR REPLACE FUNCTION unicarona.registrar_inicio_corrida()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF OLD.status IN ('ATIVA', 'LOTADA') AND NEW.status = 'EM_ANDAMENTO'
    AND OLD.iniciada_em IS NULL THEN
    NEW.iniciada_em := statement_timestamp();
  ELSE
    NEW.iniciada_em := OLD.iniciada_em;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.registrar_inicio_corrida() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS registrar_inicio_corrida ON unicarona.caronas;
CREATE TRIGGER registrar_inicio_corrida
  BEFORE UPDATE ON unicarona.caronas
  FOR EACH ROW EXECUTE FUNCTION unicarona.registrar_inicio_corrida();

CREATE OR REPLACE FUNCTION unicarona.encerrar_corridas_por_tempo(
  agora TIMESTAMPTZ DEFAULT statement_timestamp()
)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE quantidade INTEGER;
BEGIN
  WITH encerradas AS (
    UPDATE unicarona.caronas
    SET status = 'ENCERRADA_POR_TEMPO'
    WHERE status = 'EM_ANDAMENTO'
      AND COALESCE(
        iniciada_em,
        -- Sem inicio registrado, considera o ultimo inicio permitido: +2h.
        ((data_inicio + horario) AT TIME ZONE 'America/Sao_Paulo') + INTERVAL '2 hours'
      ) + INTERVAL '12 hours' <= agora
    RETURNING id_carona
  ), posicoes_removidas AS (
    DELETE FROM unicarona.posicao_atual_carona
    WHERE id_carona IN (SELECT id_carona FROM encerradas)
    RETURNING id_carona
  ), pedidos_pendentes AS (
    UPDATE unicarona.solicitacoes
    SET status = 'EXPIRADA'
    WHERE status = 'PENDENTE'
      AND id_carona IN (SELECT id_carona FROM encerradas)
    RETURNING id_solicitacao
  )
  SELECT count(*)::INTEGER INTO quantidade FROM encerradas;
  RETURN quantidade;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.encerrar_corridas_por_tempo(TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_caronas_inicio_em_andamento
  ON unicarona.caronas (iniciada_em)
  WHERE status = 'EM_ANDAMENTO';

-- A limpeza inicial e feita pelo backend apos o deploy. Nao altera viagens
-- durante a instalacao da estrutura nem inventa horarios para dados antigos.
COMMIT;
