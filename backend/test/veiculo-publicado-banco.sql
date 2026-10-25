-- Executar apos 20261025013617_preservar_veiculo_carona.sql.
-- Fixtures sinteticas: todos os registros sao revertidos ao terminar.
BEGIN;
DO $$
DECLARE
  m INTEGER; outro INTEGER; c INTEGER; nova INTEGER; r INTEGER;
  original JSONB; atual JSONB; antes BIGINT;
BEGIN
  INSERT INTO unicarona.usuarios(nome, email)
    VALUES ('QA Veiculo', gen_random_uuid()::TEXT || '@example.invalid') RETURNING id_usuario INTO m;
  INSERT INTO unicarona.usuarios(nome, email)
    VALUES ('QA Sem Veiculo', gen_random_uuid()::TEXT || '@example.invalid') RETURNING id_usuario INTO outro;
  INSERT INTO unicarona.veiculos(id_usuario, modelo, cor, placa)
    VALUES (m, 'Modelo sintetico A', 'Prata', substr(gen_random_uuid()::TEXT, 1, 10));
  SELECT jsonb_build_object('modelo', modelo, 'cor', cor, 'placa', placa) INTO original
    FROM unicarona.veiculos WHERE id_usuario=m;

  INSERT INTO unicarona.caronas(origem, destino, data_inicio, horario, vagas, valor, id_usuario, veiculo_publicado)
    VALUES ('QA Origem', 'QA Destino', CURRENT_DATE+30, '18:00', 3, 5, m, '{"modelo":"FORJADO"}') RETURNING id_carona INTO c;
  IF (SELECT veiculo_publicado FROM unicarona.caronas WHERE id_carona=c) IS DISTINCT FROM original THEN
    RAISE EXCEPTION 'Captura inicial falhou ou aceitou dados forjados'; END IF;

  SELECT count(*) INTO antes FROM unicarona.notificacoes;
  UPDATE unicarona.veiculos SET modelo='Modelo sintetico B', cor='Preto' WHERE id_usuario=m;
  IF (SELECT veiculo_publicado FROM unicarona.caronas WHERE id_carona=c) IS DISTINCT FROM original THEN
    RAISE EXCEPTION 'Troca no perfil alterou carona existente'; END IF;
  IF (SELECT count(*) FROM unicarona.notificacoes) <> antes THEN
    RAISE EXCEPTION 'Troca criou notificacao indevida'; END IF;

  UPDATE unicarona.caronas SET vagas=2, status='LOTADA' WHERE id_carona=c;
  UPDATE unicarona.caronas SET status='FINALIZADA' WHERE id_carona=c;
  IF (SELECT veiculo_publicado FROM unicarona.caronas WHERE id_carona=c) IS DISTINCT FROM original THEN
    RAISE EXCEPTION 'Edicao ou encerramento alterou historico'; END IF;
  BEGIN
    UPDATE unicarona.caronas SET veiculo_publicado='{}' WHERE id_carona=c;
    RAISE EXCEPTION 'Snapshot mutavel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE unicarona.caronas SET id_usuario=outro WHERE id_carona=c;
    RAISE EXCEPTION 'Motorista mutavel';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  INSERT INTO unicarona.caronas(origem, destino, data_inicio, horario, vagas, valor, id_usuario)
    VALUES ('QA Origem', 'QA Destino', CURRENT_DATE+31, '18:00', 3, 5, m) RETURNING id_carona INTO nova;
  SELECT veiculo_publicado INTO atual FROM unicarona.caronas WHERE id_carona=nova;
  IF atual->>'modelo' <> 'Modelo sintetico B' OR atual->>'cor' <> 'Preto' THEN
    RAISE EXCEPTION 'Nova carona nao recebeu veiculo atualizado'; END IF;

  INSERT INTO unicarona.recorrencias_carona(id_usuario, origem, destino, origem_latitude, origem_longitude, destino_latitude, destino_longitude, data_inicio, horario, dias_semana, vagas, valor)
    VALUES(m, 'QA Origem', 'QA Destino', -21, -50, -21.1, -50.1, CURRENT_DATE+30, '18:00', ARRAY[1], 2, 5) RETURNING id_recorrencia INTO r;
  INSERT INTO unicarona.caronas(origem, destino, data_inicio, horario, vagas, valor, id_usuario, id_recorrencia, data_ocorrencia, recorrente)
    VALUES ('QA Origem', 'QA Destino', CURRENT_DATE+32, '18:00', 2, 5, m, r, CURRENT_DATE+32, false) RETURNING id_carona INTO nova;
  IF (SELECT veiculo_publicado FROM unicarona.caronas WHERE id_carona=nova) IS DISTINCT FROM atual THEN
    RAISE EXCEPTION 'Ocorrencia nao capturou veiculo'; END IF;

  INSERT INTO unicarona.caronas(origem, destino, data_inicio, horario, vagas, valor, id_usuario)
    VALUES ('QA Legado', 'QA Destino', CURRENT_DATE+31, '18:00', 3, 5, outro) RETURNING id_carona INTO nova;
  IF (SELECT veiculo_publicado FROM unicarona.caronas WHERE id_carona=nova) IS NOT NULL THEN
    RAISE EXCEPTION 'Veiculo inventado para usuario sem cadastro'; END IF;
  IF has_function_privilege('anon','unicarona.preservar_veiculo_carona()','EXECUTE')
    OR has_function_privilege('authenticated','unicarona.preservar_veiculo_carona()','EXECUTE') THEN
    RAISE EXCEPTION 'Funcao exposta'; END IF;
END;
$$;
SELECT 'PASSOU: captura, antiforja, historico, notificacoes, imutabilidade, nova publicacao, recorrencia, legado e permissoes' AS resultado;
ROLLBACK;
