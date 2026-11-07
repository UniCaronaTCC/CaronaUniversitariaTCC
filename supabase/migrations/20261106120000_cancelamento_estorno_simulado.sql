BEGIN;
SET LOCAL lock_timeout = '5s';

ALTER TABLE unicarona.pagamentos
  ADD COLUMN IF NOT EXISTS estorno_simulado_em timestamptz,
  ADD COLUMN IF NOT EXISTS participacao_encerrada_em timestamptz;

-- Apenas o tratamento local do protótipo. O estado do provedor é preservado.
-- Regulariza registros antigos encerrados, sem enviar avisos retroativos.
UPDATE unicarona.pagamentos p SET participacao_encerrada_em = CURRENT_TIMESTAMP,
  estorno_simulado_em = CASE WHEN p.modo_teste AND p.status_provedor = 'PAID'
    THEN CURRENT_TIMESTAMP ELSE NULL END
FROM unicarona.solicitacoes s JOIN unicarona.caronas c ON c.id_carona = s.id_carona
WHERE p.id_solicitacao = s.id_solicitacao AND p.participacao_encerrada_em IS NULL
  AND (c.status = 'CANCELADA' OR s.status IN ('CANCELADA_PASSAGEIRO','CANCELADA_MOTORISTA','EXPIRADA'));

CREATE OR REPLACE FUNCTION unicarona.preparar_estorno_simulado()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.participacao_encerrada_em IS NOT NULL THEN
    NEW.participacao_encerrada_em := OLD.participacao_encerrada_em;
  ELSIF EXISTS (
    SELECT 1 FROM unicarona.solicitacoes s JOIN unicarona.caronas c ON c.id_carona = s.id_carona
    WHERE s.id_solicitacao = NEW.id_solicitacao
      AND (c.status = 'CANCELADA' OR s.status IN ('CANCELADA_PASSAGEIRO','CANCELADA_MOTORISTA','EXPIRADA'))
  ) THEN
    NEW.participacao_encerrada_em := CURRENT_TIMESTAMP;
  END IF;
  -- Uma resposta antiga da API não pode apagar um estorno já registrado.
  IF TG_OP = 'UPDATE' AND OLD.estorno_simulado_em IS NOT NULL THEN
    NEW.estorno_simulado_em := OLD.estorno_simulado_em;
  ELSIF NEW.modo_teste AND NEW.status_provedor = 'PAID' AND NEW.participacao_encerrada_em IS NOT NULL THEN
    NEW.estorno_simulado_em := CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION unicarona.estornar_participacao_encerrada()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
BEGIN
  -- Bloqueia também tentativas pendentes: uma confirmação concorrente precisa
  -- observar o encerramento. A data continua válida se o pedido for reutilizado.
  UPDATE unicarona.pagamentos
    SET participacao_encerrada_em = coalesce(participacao_encerrada_em, CURRENT_TIMESTAMP)
    WHERE id_solicitacao = NEW.id_solicitacao;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION unicarona.cancelar_participacoes_carona()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE pedido RECORD; pago BOOLEAN; refs JSONB;
BEGIN
  IF OLD.status NOT IN ('ATIVA', 'LOTADA') THEN
    RAISE EXCEPTION 'Só é possível cancelar a carona antes do início' USING ERRCODE = '23514';
  END IF;
  FOR pedido IN SELECT id_solicitacao, id_passageiro FROM unicarona.solicitacoes
    WHERE id_carona = NEW.id_carona AND status IN ('PENDENTE','ACEITA')
    ORDER BY id_solicitacao FOR UPDATE
  LOOP
    SELECT EXISTS(SELECT 1 FROM unicarona.pagamentos
      WHERE id_solicitacao = pedido.id_solicitacao AND modo_teste AND status_provedor = 'PAID'
        AND estorno_simulado_em IS NULL) INTO pago;
    refs := jsonb_build_object('tela','HISTORICO','idCarona',NEW.id_carona,
      'idSolicitacao',pedido.id_solicitacao,'estornoSimulado',pago);
    -- O aviso precede a atualização: o estorno não emite uma segunda notificação
    -- quando o cancelamento já informou o mesmo resultado ao passageiro.
    PERFORM unicarona.registrar_notificacao(pedido.id_passageiro, 'CARONA', 'Carona cancelada pelo motorista',
      CASE WHEN pago THEN 'O motorista cancelou sua carona. O estorno do seu pagamento foi registrado em modo de simulação, sem movimentação de dinheiro real.'
        ELSE 'O motorista cancelou sua carona. Sua reserva foi cancelada e não é necessário realizar o pagamento.' END,
      refs, 'cancelamento-carona:' || NEW.id_carona::TEXT || ':' || pedido.id_solicitacao::TEXT);
    UPDATE unicarona.solicitacoes SET status = 'CANCELADA_MOTORISTA', atualizado_em = CURRENT_TIMESTAMP
      WHERE id_solicitacao = pedido.id_solicitacao;
  END LOOP;
  PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'CARONA', 'Carona cancelada',
    'Sua carona foi cancelada. Os passageiros foram avisados e os estornos simulados foram registrados quando aplicáveis.',
    jsonb_build_object('tela','HISTORICO','idCarona',NEW.id_carona), 'cancelamento-carona:' || NEW.id_carona::TEXT);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION unicarona.registrar_evento_notificacao()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  motorista INTEGER;
  passageiro INTEGER;
  destinatario INTEGER;
  nome TEXT;
  destino TEXT;
  titulo TEXT;
  descricao TEXT;
  refs JSONB;
  chave TEXT;
  aviso RECORD;
BEGIN
  CASE TG_TABLE_NAME
  WHEN 'mensagens' THEN
    SELECT s.id_passageiro, c.id_usuario, u.nome, c.destino, s.id_solicitacao
      INTO aviso
      FROM unicarona.conversas co
      JOIN unicarona.solicitacoes s ON s.id_solicitacao = co.id_solicitacao
      JOIN unicarona.caronas c ON c.id_carona = s.id_carona
      JOIN unicarona.usuarios u ON u.id_usuario = NEW.id_remetente
      WHERE co.id_conversa = NEW.id_conversa;
    IF NEW.id_remetente = aviso.id_passageiro THEN destinatario := aviso.id_usuario;
    ELSIF NEW.id_remetente = aviso.id_usuario THEN destinatario := aviso.id_passageiro;
    ELSE RETURN NEW;
    END IF;
    IF destinatario IS NOT NULL AND destinatario <> NEW.id_remetente THEN
      PERFORM unicarona.registrar_notificacao(destinatario, 'MENSAGEM', 'Nova mensagem',
        aviso.nome || ' enviou uma mensagem na carona para ' || aviso.destino,
        jsonb_build_object('tela', 'CONVERSA', 'idSolicitacao', aviso.id_solicitacao),
        'mensagem:' || NEW.id_mensagem::TEXT);
    END IF;

  WHEN 'solicitacoes' THEN
    IF TG_OP = 'UPDATE' AND OLD.status = NEW.status THEN RETURN NEW; END IF;
    -- O cancelamento da viagem inteira possui um único aviso próprio.
    IF NEW.status = 'CANCELADA_MOTORISTA' AND EXISTS (
      SELECT 1 FROM unicarona.caronas WHERE id_carona = NEW.id_carona AND status = 'CANCELADA'
    ) THEN RETURN NEW; END IF;
    SELECT c.id_usuario, c.destino, u.nome INTO motorista, destino, nome
      FROM unicarona.caronas c JOIN unicarona.usuarios u ON u.id_usuario = NEW.id_passageiro
      WHERE c.id_carona = NEW.id_carona;
    refs := jsonb_build_object('tela', 'SOLICITACOES', 'aba', 'ENVIADAS', 'idCarona', NEW.id_carona, 'idSolicitacao', NEW.id_solicitacao);
    chave := 'solicitacao:' || NEW.id_solicitacao::TEXT || ':' || NEW.status || ':' || pg_current_xact_id()::TEXT;
    CASE NEW.status
    WHEN 'PENDENTE' THEN
      PERFORM unicarona.registrar_notificacao(motorista, 'SOLICITACAO', 'Nova solicitação de carona',
        nome || ' solicitou uma vaga para ' || destino, refs || jsonb_build_object('aba', 'RECEBIDAS'), chave);
    WHEN 'ACEITA' THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_passageiro, 'SOLICITACAO', 'Solicitação aceita',
        'Sua solicitação para ' || destino || ' foi aceita. Confira o pagamento e o embarque.', refs, chave);
    WHEN 'RECUSADA' THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_passageiro, 'SOLICITACAO', 'Solicitação recusada',
        'Sua solicitação para ' || destino || ' foi recusada.', refs, chave);
    WHEN 'CANCELADA_PASSAGEIRO' THEN
      PERFORM unicarona.registrar_notificacao(motorista, 'SOLICITACAO', 'Participação cancelada',
        nome || ' cancelou a participação na carona para ' || destino, refs || jsonb_build_object('aba', 'RECEBIDAS'), chave);
    WHEN 'CANCELADA_MOTORISTA' THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_passageiro, 'SOLICITACAO', 'Participação cancelada',
        'O motorista cancelou sua participação na carona para ' || destino, refs, chave);
    WHEN 'EXPIRADA' THEN
      refs := refs || jsonb_build_object('tela', 'HISTORICO');
      PERFORM unicarona.registrar_notificacao(NEW.id_passageiro, 'SOLICITACAO', 'Solicitação expirada',
        'Sua solicitação para ' || destino || ' expirou.', refs, chave);
    ELSE NULL;
    END CASE;

  WHEN 'caronas' THEN
    refs := jsonb_build_object('tela', 'CARONA', 'idCarona', NEW.id_carona);
    chave := 'carona:' || NEW.id_carona::TEXT || ':' || pg_current_xact_id()::TEXT;
    IF TG_OP = 'INSERT' THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'CARONA', 'Carona publicada',
        'Sua carona para ' || NEW.destino || ' foi publicada.', refs, chave || ':criada');
      RETURN NEW;
    END IF;
    IF NEW.status = 'CANCELADA' THEN RETURN NEW; END IF;
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('EM_ANDAMENTO', 'FINALIZADA', 'EXPIRADA') THEN
      titulo := CASE NEW.status WHEN 'EM_ANDAMENTO' THEN 'Carona iniciada'
        WHEN 'FINALIZADA' THEN 'Carona encerrada' ELSE 'Carona expirada' END;
      descricao := 'A carona para ' || NEW.destino || ' teve seu estado atualizado.';
      chave := chave || ':' || NEW.status;
      PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'CARONA', titulo, descricao, refs, chave);
    ELSIF ROW(OLD.origem, OLD.destino, OLD.data_inicio, OLD.horario, OLD.valor) IS DISTINCT FROM
          ROW(NEW.origem, NEW.destino, NEW.data_inicio, NEW.horario, NEW.valor) THEN
      titulo := 'Carona alterada';
      descricao := 'Confira os novos dados da carona para ' || NEW.destino || '.';
      chave := chave || ':editada';
    ELSE RETURN NEW;
    END IF;
    FOR destinatario IN SELECT DISTINCT id_passageiro FROM unicarona.solicitacoes
      WHERE id_carona = NEW.id_carona AND status IN ('PENDENTE', 'ACEITA') LOOP
      PERFORM unicarona.registrar_notificacao(destinatario, 'CARONA', titulo, descricao, refs, chave);
    END LOOP;

  WHEN 'pagamentos' THEN
    SELECT s.id_passageiro, c.id_usuario, c.destino, s.id_carona INTO aviso
      FROM unicarona.solicitacoes s JOIN unicarona.caronas c ON c.id_carona = s.id_carona
      WHERE s.id_solicitacao = NEW.id_solicitacao;
    refs := jsonb_build_object('tela', 'SOLICITACOES', 'aba', 'ENVIADAS', 'idSolicitacao', NEW.id_solicitacao, 'idCarona', aviso.id_carona);
    chave := 'pagamento:' || NEW.id_pagamento::TEXT || ':';
    IF NEW.estorno_simulado_em IS NOT NULL THEN
      IF (TG_OP = 'INSERT' OR OLD.estorno_simulado_em IS NULL) AND NOT EXISTS (
        SELECT 1 FROM unicarona.notificacoes
        WHERE id_usuario = aviso.id_passageiro
          AND chave_evento = 'cancelamento-carona:' || aviso.id_carona::TEXT || ':' || NEW.id_solicitacao::TEXT
          AND referencias @> '{"estornoSimulado":true}'::jsonb
      ) THEN
        PERFORM unicarona.registrar_notificacao(aviso.id_passageiro, 'PAGAMENTO', 'Estorno simulado registrado',
          'Sua participação foi encerrada. O estorno do pagamento de teste foi registrado, sem movimentação de dinheiro real.',
          refs || jsonb_build_object('tela', 'HISTORICO', 'estornoSimulado', true),
          'estorno-simulado:' || NEW.id_pagamento::TEXT);
      END IF;
      RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.status_provedor IS NOT DISTINCT FROM NEW.status_provedor THEN
      IF OLD.status_criacao IS DISTINCT FROM NEW.status_criacao AND NEW.status_criacao IN ('FALHOU', 'INCERTA') THEN
        PERFORM unicarona.registrar_notificacao(aviso.id_passageiro, 'PAGAMENTO', 'Confira seu pagamento',
          'Não foi possível confirmar a cobrança. Consulte o pagamento antes de tentar novamente.', refs, chave || NEW.status_criacao);
      END IF;
      RETURN NEW;
    END IF;
    IF NEW.status_provedor IS NULL THEN RETURN NEW; END IF;
    titulo := CASE NEW.status_provedor WHEN 'PENDING' THEN 'Pix disponível' WHEN 'PAID' THEN 'Pagamento confirmado'
      WHEN 'EXPIRED' THEN 'Pix expirado' WHEN 'CANCELLED' THEN 'Pagamento cancelado'
      WHEN 'REFUNDED' THEN 'Pagamento reembolsado' WHEN 'FAILED' THEN 'Pagamento não concluído'
      ELSE 'Pagamento atualizado' END;
    descricao := 'Confira o pagamento da carona para ' || aviso.destino || '.';
    PERFORM unicarona.registrar_notificacao(aviso.id_passageiro, 'PAGAMENTO', titulo, descricao, refs, chave || NEW.status_provedor);
    IF NEW.status_provedor = 'PAID' THEN
      PERFORM unicarona.registrar_notificacao(aviso.id_usuario, 'PAGAMENTO', titulo, descricao, refs || jsonb_build_object('aba', 'RECEBIDAS'), chave || NEW.status_provedor);
    END IF;

  WHEN 'avaliacoes' THEN
    PERFORM unicarona.registrar_notificacao(NEW.id_avaliado, 'AVALIACAO', 'Nova avaliação recebida',
      'Você recebeu uma avaliação de ' || NEW.nota::TEXT || ' estrelas.',
      jsonb_build_object('tela', 'AVALIACOES'), 'avaliacao:' || NEW.id_avaliacao::TEXT);

  WHEN 'usuarios' THEN
    -- O servico grava o aceite ao concluir cada tentativa, inclusive recusada.
    IF NEW.status_verificacao_cnh IN ('APROVADA', 'RECUSADA') AND
      (OLD.status_verificacao_cnh IS DISTINCT FROM NEW.status_verificacao_cnh
        OR OLD.cnh_verificada_em IS DISTINCT FROM NEW.cnh_verificada_em
        OR OLD.privacidade_aceita_em IS DISTINCT FROM NEW.privacidade_aceita_em) THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'CNH',
        CASE NEW.status_verificacao_cnh WHEN 'APROVADA' THEN 'CNH conferida' ELSE 'Confira a verificação da CNH' END,
        'O resultado da leitura da sua CNH está disponível.', jsonb_build_object('tela', 'CNH'),
        'cnh:' || NEW.id_usuario::TEXT || ':' || pg_current_xact_id()::TEXT || ':' ||
          coalesce(NEW.privacidade_aceita_em::TEXT, 'sem-data'));
    END IF;
    IF OLD.status_verificacao IS DISTINCT FROM NEW.status_verificacao THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'PERFIL', 'Verificação do perfil atualizada',
        'Confira o estado de verificação do seu perfil.', jsonb_build_object('tela', 'PERFIL'),
        'perfil:' || NEW.id_usuario::TEXT || ':' || pg_current_xact_id()::TEXT);
    END IF;

  WHEN 'recorrencias_carona' THEN
    IF TG_OP = 'INSERT' OR OLD.ativa IS DISTINCT FROM NEW.ativa THEN
      PERFORM unicarona.registrar_notificacao(NEW.id_usuario, 'RECORRENCIA',
        CASE WHEN NEW.ativa THEN 'Recorrência ativa' ELSE 'Recorrência pausada' END,
        'Confira sua programação de caronas para ' || NEW.destino || '.',
        jsonb_build_object('tela', 'RECORRENCIAS'),
        'recorrencia:' || NEW.id_recorrencia::TEXT || ':' || NEW.ativa::TEXT || ':' || pg_current_xact_id()::TEXT);
    END IF;
  ELSE NULL;
  END CASE;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION unicarona.preparar_estorno_simulado() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION unicarona.estornar_participacao_encerrada() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION unicarona.cancelar_participacoes_carona() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION unicarona.registrar_evento_notificacao() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS preparar_estorno_simulado ON unicarona.pagamentos;
CREATE TRIGGER preparar_estorno_simulado BEFORE INSERT OR UPDATE ON unicarona.pagamentos
  FOR EACH ROW EXECUTE FUNCTION unicarona.preparar_estorno_simulado();
DROP TRIGGER IF EXISTS estornar_participacao_encerrada ON unicarona.solicitacoes;
CREATE TRIGGER estornar_participacao_encerrada AFTER UPDATE OF status ON unicarona.solicitacoes
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('CANCELADA_PASSAGEIRO','CANCELADA_MOTORISTA','EXPIRADA'))
  EXECUTE FUNCTION unicarona.estornar_participacao_encerrada();
DROP TRIGGER IF EXISTS aplicar_cancelamento_carona ON unicarona.caronas;
CREATE TRIGGER aplicar_cancelamento_carona AFTER UPDATE OF status ON unicarona.caronas
  FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'CANCELADA')
  EXECUTE FUNCTION unicarona.cancelar_participacoes_carona();
DROP TRIGGER IF EXISTS central_notificar_pagamento ON unicarona.pagamentos;
CREATE TRIGGER central_notificar_pagamento AFTER INSERT OR UPDATE OF status_provedor, status_criacao, estorno_simulado_em ON unicarona.pagamentos
  FOR EACH ROW EXECUTE FUNCTION unicarona.registrar_evento_notificacao();

COMMIT;
