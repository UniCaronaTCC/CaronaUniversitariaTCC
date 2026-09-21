BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'unicarona'
      AND table_name = 'mensagens'
      AND column_name = 'lida_em'
  ) THEN
    ALTER TABLE unicarona.mensagens
      ADD COLUMN lida_em TIMESTAMPTZ;

    -- Mensagens anteriores à funcionalidade não aparecem como novas.
    UPDATE unicarona.mensagens
    SET lida_em = criado_em;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_mensagens_nao_lidas
  ON unicarona.mensagens (id_conversa, id_remetente)
  WHERE lida_em IS NULL;

CREATE OR REPLACE FUNCTION unicarona.usuario_recebe_notificacoes_mensagens(
  topico TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM unicarona.usuarios usuario
    WHERE usuario.auth_id = (SELECT auth.uid())
      AND topico = 'usuario:' || usuario.id_usuario::TEXT
  );
$$;

REVOKE ALL ON FUNCTION
  unicarona.usuario_recebe_notificacoes_mensagens(TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION
  unicarona.usuario_recebe_notificacoes_mensagens(TEXT)
  TO authenticated;

DROP POLICY IF EXISTS chat_usuario_recebe_novas_mensagens
  ON realtime.messages;

CREATE POLICY chat_usuario_recebe_novas_mensagens
  ON realtime.messages
  FOR SELECT
  TO authenticated
  USING (
    realtime.messages.extension = 'broadcast'
    AND unicarona.usuario_recebe_notificacoes_mensagens(
      (SELECT realtime.topic())
    )
  );

CREATE OR REPLACE FUNCTION unicarona.notificar_nova_mensagem()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  id_destinatario INTEGER;
BEGIN
  PERFORM realtime.broadcast_changes(
    'conversa:' || NEW.id_conversa::TEXT,
    TG_OP,
    TG_OP,
    TG_TABLE_NAME,
    TG_TABLE_SCHEMA,
    NEW,
    OLD
  );

  SELECT CASE
    WHEN solicitacao.id_passageiro = NEW.id_remetente
      THEN carona.id_usuario
    ELSE solicitacao.id_passageiro
  END
  INTO id_destinatario
  FROM unicarona.conversas conversa
  INNER JOIN unicarona.solicitacoes solicitacao
    ON solicitacao.id_solicitacao = conversa.id_solicitacao
  INNER JOIN unicarona.caronas carona
    ON carona.id_carona = solicitacao.id_carona
  WHERE conversa.id_conversa = NEW.id_conversa;

  IF id_destinatario IS NOT NULL THEN
    PERFORM realtime.broadcast_changes(
      'usuario:' || id_destinatario::TEXT,
      TG_OP,
      TG_OP,
      TG_TABLE_NAME,
      TG_TABLE_SCHEMA,
      NEW,
      OLD
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.notificar_nova_mensagem()
  FROM PUBLIC;

COMMIT;
