BEGIN;

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
    SELECT c.id_conversa, s.id_passageiro, ca.id_usuario
    FROM unicarona.conversas c
    JOIN unicarona.solicitacoes s ON s.id_solicitacao = c.id_solicitacao
    JOIN unicarona.caronas ca ON ca.id_carona = s.id_carona
    WHERE s.id_carona = carona_alterada
      OR s.id_solicitacao = solicitacao_alterada
  LOOP
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

DROP TRIGGER IF EXISTS notificar_estado_chat_carona ON unicarona.caronas;
CREATE TRIGGER notificar_estado_chat_carona
  AFTER UPDATE OF status ON unicarona.caronas
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION unicarona.notificar_estado_conversa();

DROP TRIGGER IF EXISTS notificar_estado_chat_solicitacao ON unicarona.solicitacoes;
CREATE TRIGGER notificar_estado_chat_solicitacao
  AFTER UPDATE OF status ON unicarona.solicitacoes
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION unicarona.notificar_estado_conversa();

COMMIT;
