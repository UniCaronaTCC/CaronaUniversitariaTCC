-- Executar depois de criar_notificacoes.sql. Nenhum dado de teste e mantido.
BEGIN;
DO $$
DECLARE
  m INTEGER; p INTEGER; c INTEGER; s INTEGER; co INTEGER; pg INTEGER; r INTEGER;
  antes BIGINT; depois BIGINT;
BEGIN
  INSERT INTO unicarona.usuarios(nome, email) VALUES ('QA Notificacoes Motorista', gen_random_uuid()::TEXT || '@example.invalid') RETURNING id_usuario INTO m;
  INSERT INTO unicarona.usuarios(nome, email) VALUES ('QA Notificacoes Passageiro', gen_random_uuid()::TEXT || '@example.invalid') RETURNING id_usuario INTO p;
  INSERT INTO unicarona.caronas(origem, destino, data_inicio, horario, vagas, valor, id_usuario)
    VALUES ('Origem sintetica', 'Destino sintetico', CURRENT_DATE + 30, '18:00', 3, 10, m) RETURNING id_carona INTO c;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='CARONA') <> 1 THEN RAISE EXCEPTION 'Publicacao ausente'; END IF;

  INSERT INTO unicarona.solicitacoes(id_carona, id_passageiro, tipo_ponto_embarque, local_embarque, embarque_latitude, embarque_longitude)
    VALUES (c, p, 'NOVO', 'Embarque sintetico', -21, -50) RETURNING id_solicitacao INTO s;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='SOLICITACAO') <> 1 THEN RAISE EXCEPTION 'Solicitacao ausente'; END IF;
  IF NOT EXISTS (SELECT 1 FROM unicarona.notificacoes WHERE id_usuario=m AND referencias->>'aba'='RECEBIDAS') THEN RAISE EXCEPTION 'Aba motorista incorreta'; END IF;
  UPDATE unicarona.solicitacoes SET status='ACEITA' WHERE id_solicitacao=s;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='SOLICITACAO') <> 1 THEN RAISE EXCEPTION 'Aceite ausente'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.solicitacoes SET status='ACEITA' WHERE id_solicitacao=s;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'Aceite duplicado'; END IF;

  INSERT INTO unicarona.conversas(id_solicitacao) VALUES(s) RETURNING id_conversa INTO co;
  INSERT INTO unicarona.mensagens(id_conversa, id_remetente, conteudo) VALUES(co, p, 'SEGREDO_SINTETICO');
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='MENSAGEM') <> 1 THEN RAISE EXCEPTION 'Mensagem ausente'; END IF;
  IF EXISTS (SELECT 1 FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='MENSAGEM') THEN RAISE EXCEPTION 'Mensagem para remetente'; END IF;
  IF EXISTS (SELECT 1 FROM unicarona.notificacoes WHERE descricao LIKE '%SEGREDO_SINTETICO%') THEN RAISE EXCEPTION 'Conteudo privado copiado'; END IF;
  INSERT INTO unicarona.mensagens(id_conversa, id_remetente, conteudo) VALUES(co, m, 'Resposta sintetica');
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='MENSAGEM') <> 1 THEN RAISE EXCEPTION 'Resposta ausente'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.mensagens SET lida_em=now() WHERE id_conversa=co;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'Ler mensagem gerou aviso'; END IF;

  INSERT INTO unicarona.pagamentos(id_solicitacao, referencia, valor_centavos, status_criacao, status_provedor, id_provedor)
    VALUES(s, gen_random_uuid(), 1000, 'CONFIRMADA', 'PENDING', 'qa-' || gen_random_uuid()::TEXT) RETURNING id_pagamento INTO pg;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='PAGAMENTO') <> 1 THEN RAISE EXCEPTION 'Pix ausente'; END IF;
  UPDATE unicarona.pagamentos SET status_provedor='PAID' WHERE id_pagamento=pg;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='PAGAMENTO') <> 2 THEN RAISE EXCEPTION 'Pagamento passageiro ausente'; END IF;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='PAGAMENTO') <> 1 THEN RAISE EXCEPTION 'Pagamento motorista ausente'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.pagamentos SET status_provedor='PAID' WHERE id_pagamento=pg;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'Pagamento duplicado'; END IF;

  UPDATE unicarona.caronas SET status='LOTADA' WHERE id_carona=c;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'Vaga gerou aviso redundante'; END IF;
  UPDATE unicarona.caronas SET destino='Destino atualizado' WHERE id_carona=c;
  IF NOT EXISTS (SELECT 1 FROM unicarona.notificacoes WHERE id_usuario=p AND titulo='Carona alterada') THEN RAISE EXCEPTION 'Edicao ausente'; END IF;
  UPDATE unicarona.caronas SET status='EM_ANDAMENTO' WHERE id_carona=c;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario IN(m,p) AND titulo='Carona iniciada') <> 2 THEN RAISE EXCEPTION 'Inicio ausente'; END IF;
  UPDATE unicarona.caronas SET status='FINALIZADA' WHERE id_carona=c;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario IN(m,p) AND titulo='Carona encerrada') <> 2 THEN RAISE EXCEPTION 'Fim ausente'; END IF;
  INSERT INTO unicarona.avaliacoes(id_solicitacao, id_avaliador, id_avaliado, nota) VALUES(s,p,m,5);
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='AVALIACAO') <> 1 THEN RAISE EXCEPTION 'Avaliacao ausente'; END IF;

  UPDATE unicarona.usuarios SET status_verificacao_cnh='RECUSADA', cnh_verificada_em=NULL, privacidade_aceita_em=now() WHERE id_usuario=p;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='CNH') <> 1 THEN RAISE EXCEPTION 'CNH ausente'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.usuarios SET status_verificacao_cnh='RECUSADA', cnh_verificada_em=cnh_verificada_em WHERE id_usuario=p;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'Regravacao de CNH duplicou aviso'; END IF;
  UPDATE unicarona.usuarios SET status_verificacao_cnh='RECUSADA', cnh_verificada_em=NULL, privacidade_aceita_em=now()+interval '1 second' WHERE id_usuario=p;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND tipo='CNH') <> 2 THEN RAISE EXCEPTION 'Novo resultado recusado sem aviso'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.usuarios SET status_verificacao_cnh='RECUSADA', privacidade_aceita_em=privacidade_aceita_em WHERE id_usuario=p;
  UPDATE unicarona.usuarios SET nome='QA Notificacoes Passageiro Atualizado' WHERE id_usuario=p;
  UPDATE unicarona.usuarios SET status_verificacao_cnh='NAO_ENVIADA', cnh_verificada_em=NULL WHERE id_usuario=p;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN RAISE EXCEPTION 'CNH redundante'; END IF;

  INSERT INTO unicarona.recorrencias_carona(id_usuario, origem, destino, origem_latitude, origem_longitude, destino_latitude, destino_longitude, data_inicio, horario, dias_semana, vagas, valor)
    VALUES(m, 'Origem QA', 'Destino QA', -21, -50, -21.1, -50.1, CURRENT_DATE + 30, '18:00', ARRAY[1], 2, 10) RETURNING id_recorrencia INTO r;
  UPDATE unicarona.recorrencias_carona SET ativa=false WHERE id_recorrencia=r;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND tipo='RECORRENCIA') <> 2 THEN RAISE EXCEPTION 'Recorrencia ausente'; END IF;

  PERFORM unicarona.registrar_notificacao(m,'CARONA','Teste deduplicado','Sintetico','{}','qa-deduplicacao');
  PERFORM unicarona.registrar_notificacao(m,'CARONA','Teste deduplicado','Sintetico','{}','qa-deduplicacao');
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND chave_evento='qa-deduplicacao') <> 1 THEN RAISE EXCEPTION 'Evento duplicado'; END IF;
  SELECT count(*) INTO antes FROM unicarona.notificacoes WHERE id_usuario=p AND lida_em IS NULL;
  UPDATE unicarona.notificacoes SET lida_em=now() WHERE id_usuario=m AND lida_em IS NULL;
  IF EXISTS (SELECT 1 FROM unicarona.notificacoes WHERE id_usuario=m AND lida_em IS NULL) THEN RAISE EXCEPTION 'Leitura incompleta'; END IF;
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=p AND lida_em IS NULL) <> antes THEN RAISE EXCEPTION 'Leitura vazou entre contas'; END IF;
  PERFORM unicarona.registrar_notificacao(m,'CARONA','Novo depois da leitura','Sintetico','{}','qa-posterior');
  IF (SELECT count(*) FROM unicarona.notificacoes WHERE id_usuario=m AND lida_em IS NULL) <> 1 THEN RAISE EXCEPTION 'Aviso futuro foi lido'; END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='unicarona.notificacoes'::regclass) THEN RAISE EXCEPTION 'RLS ausente'; END IF;
  IF has_table_privilege('anon','unicarona.notificacoes','SELECT') OR has_table_privilege('authenticated','unicarona.notificacoes','UPDATE') THEN RAISE EXCEPTION 'Acesso direto exposto'; END IF;
END;
$$;
SELECT 'PASSOU: geracao, deduplicacao, leitura, conta, privacidade e RLS; rollback a seguir' AS resultado;
ROLLBACK;
