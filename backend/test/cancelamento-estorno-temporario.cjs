// SQL isolado: pg_temp por padrão; --concorrencia cria e remove um esquema
// sintético exclusivo para duas conexões. Não escreve nas tabelas do aplicativo.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { randomBytes } = require('node:crypto');
const { Client } = require('pg');
require('dotenv').config({
  path: path.join(__dirname, '../.env'),
  quiet: true,
});

async function executar() {
  const config = {
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    ssl:
      process.env.DB_SSL === 'true'
        ? {
            rejectUnauthorized:
              process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
          }
        : undefined,
    connectionTimeoutMillis: 10000,
  };
  const concorrente = process.argv.includes('--concorrencia');
  const schema = concorrente
    ? `buscaeu_teste_estorno_${randomBytes(6).toString('hex')}`
    : 'pg_temp';
  assert(!concorrente || /^buscaeu_teste_estorno_[a-f0-9]{12}$/.test(schema));
  const client = new Client(config);
  const query = client.query.bind(client);
  client.query = (sql, parametros) =>
    query(sql.replaceAll('pg_temp.', `${schema}.`), parametros);
  let schemaCriado = false;
  let passou = 0;
  try {
    await client.connect();
    if (concorrente) {
      // Espaço isolado e descartável para duas conexões; nunca usa tabelas do app.
      await client.query(`CREATE SCHEMA ${schema}`);
      schemaCriado = true;
      await client.query(`SET search_path TO ${schema}`);
    }
    await client.query('BEGIN');
    await client.query("SET LOCAL statement_timeout = '10s'");
    await client.query(
      `
      CREATE TEMP TABLE usuarios (id_usuario integer PRIMARY KEY, nome text);
      CREATE TEMP TABLE caronas (
        id_carona integer PRIMARY KEY, id_usuario integer, status text,
        origem text DEFAULT 'Origem fictícia', destino text DEFAULT 'Destino fictício',
        data_inicio date DEFAULT '2030-01-01', horario time DEFAULT '18:00', valor numeric DEFAULT 1
      );
      CREATE TEMP TABLE solicitacoes (
        id_solicitacao integer PRIMARY KEY, id_carona integer, id_passageiro integer,
        status text, atualizado_em timestamptz DEFAULT CURRENT_TIMESTAMP
      );
      CREATE TEMP TABLE pagamentos (
        id_pagamento integer PRIMARY KEY, id_solicitacao integer,
        modo_teste boolean DEFAULT true, status_provedor text,
        status_criacao text DEFAULT 'CONFIRMADA'
      );
      CREATE TEMP TABLE notificacoes (
        id_notificacao integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_usuario integer, tipo text, titulo text, descricao text,
        referencias jsonb, chave_evento text,
        UNIQUE (id_usuario, chave_evento)
      );
      CREATE FUNCTION pg_temp.registrar_notificacao(integer,text,text,text,jsonb,text)
      RETURNS void LANGUAGE sql AS $stub$
        INSERT INTO pg_temp.notificacoes(id_usuario,tipo,titulo,descricao,referencias,chave_evento)
        VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING;
      $stub$;
    `.replaceAll(
        'CREATE TEMP TABLE',
        concorrente ? 'CREATE TABLE' : 'CREATE TEMP TABLE',
      ),
    );
    let sql = fs.readFileSync(
      path.join(
        __dirname,
        '../../supabase/migrations/20261106120000_cancelamento_estorno_simulado.sql',
      ),
      'utf8',
    );
    sql = sql
      .replace(/^BEGIN;\s*$/m, '')
      .replace(/^COMMIT;\s*$/m, '')
      .replaceAll('unicarona.', 'pg_temp.');
    assert(
      !sql.includes('unicarona.'),
      'O teste deve usar exclusivamente pg_temp',
    );
    await client.query(sql);
    await client.query(`
      CREATE TRIGGER central_notificar_carona AFTER UPDATE OF status ON pg_temp.caronas
        FOR EACH ROW EXECUTE FUNCTION pg_temp.registrar_evento_notificacao();
      CREATE TRIGGER central_notificar_solicitacao AFTER UPDATE OF status ON pg_temp.solicitacoes
        FOR EACH ROW EXECUTE FUNCTION pg_temp.registrar_evento_notificacao();
    `);
    const temporarias =
      await client.query(`SELECT count(*)::int AS total FROM pg_class
      WHERE relnamespace = ${concorrente ? `'${schema}'::regnamespace` : 'pg_my_temp_schema()'}
      AND relname IN ('usuarios','caronas','solicitacoes','pagamentos','notificacoes')
      AND relpersistence='${concorrente ? 'p' : 't'}'`);
    assert.equal(temporarias.rows[0].total, 5);

    async function preparar(statusPagamento = 'PAID') {
      await client.query(`TRUNCATE pg_temp.notificacoes, pg_temp.pagamentos, pg_temp.solicitacoes, pg_temp.caronas, pg_temp.usuarios;
        INSERT INTO pg_temp.usuarios VALUES (1,'Motorista fictício'),(2,'Passageiro fictício'),(3,'Segundo fictício'),(4,'Terceiro fictício');
        INSERT INTO pg_temp.caronas(id_carona,id_usuario,status) VALUES (10,1,'ATIVA');
        INSERT INTO pg_temp.solicitacoes(id_solicitacao,id_carona,id_passageiro,status) VALUES (20,10,2,'ACEITA');`);
      await client.query(
        `INSERT INTO pg_temp.pagamentos(id_pagamento,id_solicitacao,status_provedor) VALUES (30,20,$1)`,
        [statusPagamento],
      );
      await client.query('TRUNCATE pg_temp.notificacoes');
    }
    async function estado() {
      const result =
        await client.query(`SELECT c.status AS carona, s.status AS pedido, p.status_provedor AS pagamento,
        p.estorno_simulado_em AS estorno FROM pg_temp.caronas c JOIN pg_temp.solicitacoes s USING(id_carona)
        JOIN pg_temp.pagamentos p USING(id_solicitacao) WHERE p.id_pagamento=30`);
      return result.rows[0];
    }
    async function teste(nome, fn) {
      await fn();
      passou++;
      console.log(`PASSOU: ${nome}`);
    }
    await teste(
      'cancelamento integral preserva PAID, encerra todos e diferencia quem pagou',
      async () => {
        await preparar();
        await client.query(`INSERT INTO pg_temp.solicitacoes(id_solicitacao,id_carona,id_passageiro,status)
        VALUES (21,10,3,'ACEITA'),(22,10,4,'PENDENTE');
        UPDATE pg_temp.caronas SET status='CANCELADA' WHERE id_carona=10;`);
        const e = await estado();
        assert.equal(e.carona, 'CANCELADA');
        assert.equal(e.pedido, 'CANCELADA_MOTORISTA');
        assert.equal(e.pagamento, 'PAID');
        assert(e.estorno);
        const pedidos = await client.query(
          'SELECT status FROM pg_temp.solicitacoes',
        );
        assert(pedidos.rows.every((r) => r.status === 'CANCELADA_MOTORISTA'));
        const avisos = await client.query(
          'SELECT id_usuario,descricao,referencias FROM pg_temp.notificacoes ORDER BY id_usuario',
        );
        assert.equal(avisos.rowCount, 4);
        assert.match(
          avisos.rows.find((n) => n.id_usuario === 2).descricao,
          /estorno.*simulação/,
        );
        assert.match(
          avisos.rows.find((n) => n.id_usuario === 3).descricao,
          /não é necessário/,
        );
        assert.match(
          avisos.rows.find((n) => n.id_usuario === 4).descricao,
          /não é necessário/,
        );
      },
    );
    await teste(
      'repetição do cancelamento e confirmação não duplica avisos nem estorno',
      async () => {
        const antes = await estado();
        await client.query(`UPDATE pg_temp.caronas SET status='CANCELADA' WHERE id_carona=10;
        UPDATE pg_temp.pagamentos SET status_provedor='PAID', estorno_simulado_em=NULL WHERE id_pagamento=30;`);
        assert.equal(
          (await estado()).estorno.getTime(),
          antes.estorno.getTime(),
        );
        assert.equal(
          (
            await client.query(
              'SELECT count(*)::int AS total FROM pg_temp.notificacoes',
            )
          ).rows[0].total,
          4,
        );
      },
    );
    await teste(
      'confirmação após cancelamento registra estorno e mantém participação cancelada',
      async () => {
        await preparar('PENDING');
        await client.query(`UPDATE pg_temp.caronas SET status='CANCELADA' WHERE id_carona=10;
        UPDATE pg_temp.pagamentos SET status_provedor='PAID' WHERE id_pagamento=30;`);
        const e = await estado();
        assert.equal(e.pedido, 'CANCELADA_MOTORISTA');
        assert(e.estorno);
        const n = await client.query(
          'SELECT titulo FROM pg_temp.notificacoes WHERE id_usuario=2 ORDER BY id_notificacao',
        );
        assert.deepEqual(
          n.rows.map((x) => x.titulo),
          ['Carona cancelada pelo motorista', 'Estorno simulado registrado'],
        );
        await client.query(
          "UPDATE pg_temp.pagamentos SET status_provedor='PAID' WHERE id_pagamento=30",
        );
        assert.equal(
          (
            await client.query(
              'SELECT count(*)::int AS total FROM pg_temp.notificacoes WHERE id_usuario=2',
            )
          ).rows[0].total,
          2,
        );
      },
    );
    await teste(
      'confirmação após expiração também é compensada apenas na simulação',
      async () => {
        await preparar('PENDING');
        await client.query(`UPDATE pg_temp.solicitacoes SET status='EXPIRADA' WHERE id_solicitacao=20;
        UPDATE pg_temp.pagamentos SET status_provedor='PAID' WHERE id_pagamento=30;`);
        const e = await estado();
        assert.equal(e.pedido, 'EXPIRADA');
        assert.equal(e.carona, 'ATIVA');
        assert(e.estorno);
      },
    );
    await teste(
      'cancelamento antes da confirmação individual não reativa a participação',
      async () => {
        await preparar('PENDING');
        await client.query(`UPDATE pg_temp.solicitacoes SET status='CANCELADA_PASSAGEIRO' WHERE id_solicitacao=20;
        UPDATE pg_temp.pagamentos SET status_provedor='PAID' WHERE id_pagamento=30;`);
        assert.equal((await estado()).pedido, 'CANCELADA_PASSAGEIRO');
        assert((await estado()).estorno);
      },
    );
    await teste(
      'pagamento ativo continua normal, sem criar estorno',
      async () => {
        await preparar('PENDING');
        await client.query(
          "UPDATE pg_temp.pagamentos SET status_provedor='PAID' WHERE id_pagamento=30",
        );
        const e = await estado();
        assert.equal(e.pedido, 'ACEITA');
        assert.equal(e.estorno, null);
        const n = await client.query(
          "SELECT count(*)::int AS total FROM pg_temp.notificacoes WHERE titulo='Pagamento confirmado'",
        );
        assert.equal(n.rows[0].total, 2);
      },
    );
    await teste(
      'tentativa antiga não paga nova reserva após reutilizar a solicitação',
      async () => {
        await preparar('PENDING');
        await client.query(`UPDATE pg_temp.solicitacoes SET status='CANCELADA_PASSAGEIRO' WHERE id_solicitacao=20;
        UPDATE pg_temp.solicitacoes SET status='ACEITA' WHERE id_solicitacao=20;
        INSERT INTO pg_temp.pagamentos(id_pagamento,id_solicitacao,status_provedor) VALUES (31,20,'PENDING');
        UPDATE pg_temp.pagamentos SET status_provedor='PAID', participacao_encerrada_em=NULL WHERE id_pagamento=30;`);
        const e = await estado();
        assert.equal(e.pedido, 'ACEITA');
        assert(e.estorno);
        const novas = await client.query(
          `SELECT estorno_simulado_em,participacao_encerrada_em,status_provedor FROM pg_temp.pagamentos WHERE id_pagamento=31`,
        );
        assert.equal(novas.rows[0].participacao_encerrada_em, null);
        assert.equal(novas.rows[0].estorno_simulado_em, null);
        assert.equal(novas.rows[0].status_provedor, 'PENDING');
      },
    );
    await teste(
      'rollback desfaz cancelamento, estorno e notificações juntos',
      async () => {
        await preparar();
        await client.query(`SAVEPOINT antes_cancelar;
        UPDATE pg_temp.caronas SET status='CANCELADA' WHERE id_carona=10;
        ROLLBACK TO SAVEPOINT antes_cancelar;`);
        const e = await estado();
        assert.equal(e.carona, 'ATIVA');
        assert.equal(e.pedido, 'ACEITA');
        assert.equal(e.estorno, null);
        assert.equal(
          (
            await client.query(
              'SELECT count(*)::int AS total FROM pg_temp.notificacoes',
            )
          ).rows[0].total,
          0,
        );
      },
    );
    await teste(
      'o banco preserva viagens iniciadas e encerradas contra cancelamento',
      async () => {
        for (const status of [
          'EM_ANDAMENTO',
          'FINALIZADA',
          'ENCERRADA_POR_TEMPO',
        ]) {
          await preparar();
          await client.query(
            'UPDATE pg_temp.caronas SET status=$1 WHERE id_carona=10',
            [status],
          );
          await client.query('SAVEPOINT recusar_cancelamento');
          await assert.rejects(
            client.query(
              "UPDATE pg_temp.caronas SET status='CANCELADA' WHERE id_carona=10",
            ),
            { code: '23514' },
          );
          await client.query('ROLLBACK TO SAVEPOINT recusar_cancelamento');
          assert.equal((await estado()).carona, status);
          assert.equal((await estado()).estorno, null);
        }
      },
    );
    if (concorrente) {
      await client.query('COMMIT');
      const confirmacao = new Client(config);
      const cancelamento = new Client(config);
      try {
        await Promise.all([confirmacao.connect(), cancelamento.connect()]);
        for (const conexao of [confirmacao, cancelamento]) {
          await conexao.query(
            `SET search_path TO ${schema}; SET statement_timeout='8s'`,
          );
        }
        async function esperarBloqueio(pid) {
          const limite = Date.now() + 5000;
          while (Date.now() < limite) {
            const resultado = await client.query(
              'SELECT cardinality(pg_blocking_pids($1)) AS bloqueios',
              [pid],
            );
            if (resultado.rows[0].bloqueios > 0) return;
            await new Promise((resolve) => setTimeout(resolve, 20));
          }
          assert.fail('A barreira não observou o bloqueio esperado');
        }
        const pidConfirmacao = (
          await confirmacao.query('SELECT pg_backend_pid() AS pid')
        ).rows[0].pid;
        const pidCancelamento = (
          await cancelamento.query('SELECT pg_backend_pid() AS pid')
        ).rows[0].pid;
        await teste(
          'confirmação em transação aberta antes do cancelamento não perde estorno',
          async () => {
            await preparar('PENDING');
            await confirmacao.query(
              'BEGIN; SELECT 1 FROM pagamentos WHERE id_pagamento=30 FOR UPDATE',
            );
            await cancelamento.query('BEGIN');
            const cancelar = cancelamento.query(
              "UPDATE caronas SET status='CANCELADA' WHERE id_carona=10",
            );
            cancelar.catch(() => {});
            await esperarBloqueio(pidCancelamento);
            await confirmacao.query(
              "UPDATE pagamentos SET status_provedor='PAID' WHERE id_pagamento=30; COMMIT",
            );
            await cancelar;
            await cancelamento.query('COMMIT');
            const e = await estado();
            assert.equal(e.pedido, 'CANCELADA_MOTORISTA');
            assert.equal(e.pagamento, 'PAID');
            assert(e.estorno);
          },
        );
        await teste(
          'cancelamento em transação aberta antes da confirmação não reativa reserva',
          async () => {
            await preparar('PENDING');
            await cancelamento.query(
              "BEGIN; UPDATE caronas SET status='CANCELADA' WHERE id_carona=10",
            );
            await confirmacao.query('BEGIN');
            const confirmar = confirmacao.query(
              "UPDATE pagamentos SET status_provedor='PAID' WHERE id_pagamento=30",
            );
            confirmar.catch(() => {});
            await esperarBloqueio(pidConfirmacao);
            await cancelamento.query('COMMIT');
            await confirmar;
            await confirmacao.query('COMMIT');
            const e = await estado();
            assert.equal(e.pedido, 'CANCELADA_MOTORISTA');
            assert(e.estorno);
            assert.equal(
              (
                await client.query(
                  "SELECT count(*)::int AS total FROM pg_temp.notificacoes WHERE titulo='Pagamento confirmado'",
                )
              ).rows[0].total,
              0,
            );
          },
        );
      } finally {
        await Promise.allSettled([
          confirmacao.query('ROLLBACK'),
          cancelamento.query('ROLLBACK'),
        ]);
        await Promise.allSettled([confirmacao.end(), cancelamento.end()]);
      }
    }
    console.log(
      `${passou} cenários SQL passaram; nenhum broadcast ou registro do aplicativo alterado.`,
    );
  } finally {
    try {
      await client.query('ROLLBACK');
      if (schemaCriado) await client.query(`DROP SCHEMA ${schema} CASCADE`);
    } finally {
      await client.end();
    }
  }
}
executar().catch((error) => {
  console.error(error.code || error.message);
  process.exitCode = 1;
});
