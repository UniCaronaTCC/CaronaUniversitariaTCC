BEGIN;

ALTER TABLE unicarona.conversas
  ADD COLUMN IF NOT EXISTS encerrada_em TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION unicarona.notificar_estado_conversa()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  carona_alterada INTEGER;
  solicitacao_alterada INTEGER;
  conversa RECORD;
  aviso JSONB;
BEGIN
  IF TG_TABLE_NAME = 'caronas' THEN
    carona_alterada := NEW.id_carona;
  ELSE
    solicitacao_alterada := NEW.id_solicitacao;
  END IF;

  FOR conversa IN
    SELECT c.id_conversa, s.id_passageiro, ca.id_usuario,
      s.status AS status_solicitacao, ca.status AS status_carona
    FROM unicarona.conversas c
    JOIN unicarona.solicitacoes s ON s.id_solicitacao = c.id_solicitacao
    JOIN unicarona.caronas ca ON ca.id_carona = s.id_carona
    WHERE s.id_carona = carona_alterada
      OR s.id_solicitacao = solicitacao_alterada
  LOOP
    UPDATE unicarona.conversas
    SET encerrada_em = CASE
      WHEN conversa.status_solicitacao <> 'ACEITA'
        OR conversa.status_carona NOT IN ('ATIVA', 'LOTADA', 'EM_ANDAMENTO')
      THEN COALESCE(encerrada_em, CURRENT_TIMESTAMP)
      ELSE NULL
    END
    WHERE id_conversa = conversa.id_conversa;

    aviso := jsonb_build_object('idConversa', conversa.id_conversa);
    PERFORM realtime.send(
      aviso, 'CONVERSA_ATUALIZADA',
      'conversa:' || conversa.id_conversa::TEXT, true
    );
    PERFORM realtime.send(
      aviso, 'CONVERSA_ATUALIZADA',
      'usuario:' || conversa.id_passageiro::TEXT, true
    );
    PERFORM realtime.send(
      aviso, 'CONVERSA_ATUALIZADA',
      'usuario:' || conversa.id_usuario::TEXT, true
    );
  END LOOP;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.notificar_estado_conversa() FROM PUBLIC;

-- O horario original das conversas antigas nao foi registrado.
-- Iniciamos o prazo agora, sem inferir encerramento pela data da viagem.
UPDATE unicarona.conversas c
SET encerrada_em = CURRENT_TIMESTAMP
FROM unicarona.solicitacoes s
JOIN unicarona.caronas ca ON ca.id_carona = s.id_carona
WHERE c.id_solicitacao = s.id_solicitacao
  AND c.encerrada_em IS NULL
  AND (s.status <> 'ACEITA'
    OR ca.status NOT IN ('ATIVA', 'LOTADA', 'EM_ANDAMENTO'));

COMMIT;
