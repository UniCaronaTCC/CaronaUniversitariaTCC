// Teste de PostgreSQL com esquema isolado e ROLLBACK; nao inicia jobs do app.
require('dotenv/config');
const { Client } = require('pg');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

async function executar() {
  const cliente = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    ssl:
      process.env.DB_SSL === 'true'
        ? {
            rejectUnauthorized:
              process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
          }
        : false,
    connectionTimeoutMillis: 10000,
  });
  await cliente.connect();
  const esquema = `qa_corridas_${randomUUID().replaceAll('-', '')}`;
  try {
    await cliente.query('BEGIN');
    await cliente.query(
      "SET LOCAL lock_timeout = '3s'; SET LOCAL statement_timeout = '30s'",
    );
    await cliente.query(`CREATE SCHEMA ${esquema};
      CREATE TABLE ${esquema}.caronas (id_carona INTEGER PRIMARY KEY, status TEXT NOT NULL,
        data_inicio DATE NOT NULL, horario TIME NOT NULL);
      CREATE TABLE ${esquema}.posicao_atual_carona (id_carona INTEGER PRIMARY KEY);
      CREATE TABLE ${esquema}.solicitacoes (id_solicitacao INTEGER PRIMARY KEY, id_carona INTEGER, status TEXT);
      CREATE TABLE ${esquema}.pagamentos (id INTEGER PRIMARY KEY, status TEXT);
      CREATE TABLE ${esquema}.pontos_embarque (id INTEGER PRIMARY KEY, percorrido_em TIMESTAMPTZ);`);
    const migracao = readFileSync(
      resolve(
        __dirname,
        '../../supabase/migrations/20261030140000_encerrar_corridas_por_tempo.sql',
      ),
      'utf8',
    )
      .replace(/^BEGIN;\s*/, '')
      .replace(/COMMIT;\s*$/, '')
      .replaceAll('unicarona.', `${esquema}.`);
    await cliente.query(migracao);
    // Tambem verifica que a instalacao e repetivel.
    await cliente.query(migracao);
    const agora = new Date('2026-10-30T15:00:00Z');
    const h = 3600000;
    const inserir = (
      id,
      status,
      inicio,
      data = '2026-10-30',
      horario = '08:00',
    ) =>
      cliente.query(`INSERT INTO ${esquema}.caronas VALUES ($1,$2,$3,$4,$5)`, [
        id,
        status,
        data,
        horario,
        inicio,
      ]);
    await inserir(1, 'EM_ANDAMENTO', new Date(agora - h * 12));
    await inserir(2, 'EM_ANDAMENTO', new Date(agora - h * 12 + 1));
    await inserir(3, 'EM_ANDAMENTO', null, '2026-10-27');
    // Horario marcado 02h BRT (05h UTC): ultimo inicio permitido 07h UTC.
    await inserir(4, 'EM_ANDAMENTO', null, '2026-10-30', '02:00');
    await inserir(5, 'FINALIZADA', new Date(agora - h * 24));
    await inserir(6, 'CANCELADA', new Date(agora - h * 24));
    await inserir(7, 'ATIVA', null, '2026-10-27');
    await inserir(8, 'LOTADA', null, '2026-10-27');
    await cliente.query(`INSERT INTO ${esquema}.posicao_atual_carona VALUES (1),(2),(3);
      INSERT INTO ${esquema}.solicitacoes VALUES (1,1,'PENDENTE'),(2,1,'ACEITA');
      INSERT INTO ${esquema}.pagamentos VALUES (1,'PAID');
      INSERT INTO ${esquema}.pontos_embarque VALUES (1,NULL);`);
    const encerrar = (data) =>
      cliente.query(`SELECT ${esquema}.encerrar_corridas_por_tempo($1) AS n`, [
        data,
      ]);
    assert.equal((await encerrar(agora)).rows[0].n, 2);
    const estados = (
      await cliente.query(
        `SELECT id_carona,status FROM ${esquema}.caronas ORDER BY id_carona`,
      )
    ).rows;
    assert.deepEqual(
      estados.map((x) => x.status),
      [
        'ENCERRADA_POR_TEMPO',
        'EM_ANDAMENTO',
        'ENCERRADA_POR_TEMPO',
        'EM_ANDAMENTO',
        'FINALIZADA',
        'CANCELADA',
        'ATIVA',
        'LOTADA',
      ],
    );
    assert.deepEqual(
      (
        await cliente.query(
          `SELECT id_carona FROM ${esquema}.posicao_atual_carona`,
        )
      ).rows,
      [{ id_carona: 2 }],
    );
    assert.deepEqual(
      (
        await cliente.query(
          `SELECT status FROM ${esquema}.solicitacoes ORDER BY id_solicitacao`,
        )
      ).rows.map((x) => x.status),
      ['EXPIRADA', 'ACEITA'],
    );
    assert.equal(
      (await cliente.query(`SELECT status FROM ${esquema}.pagamentos`)).rows[0]
        .status,
      'PAID',
    );
    assert.equal(
      (
        await cliente.query(
          `SELECT percorrido_em FROM ${esquema}.pontos_embarque`,
        )
      ).rows[0].percorrido_em,
      null,
    );
    assert.equal((await encerrar(agora)).rows[0].n, 0);
    // As duas horas adicionais do legado sao respeitadas ate o limite exato.
    await encerrar(new Date('2026-10-30T18:59:59.999Z'));
    assert.equal(
      (
        await cliente.query(
          `SELECT status FROM ${esquema}.caronas WHERE id_carona=4`,
        )
      ).rows[0].status,
      'EM_ANDAMENTO',
    );
    await encerrar(new Date('2026-10-30T19:00:00Z'));
    assert.equal(
      (
        await cliente.query(
          `SELECT status FROM ${esquema}.caronas WHERE id_carona=4`,
        )
      ).rows[0].status,
      'ENCERRADA_POR_TEMPO',
    );
    // Comeco real registrado pelo banco, preservado depois de reenvios/edicoes.
    await inserir(9, 'ATIVA', null);
    await cliente.query(
      `UPDATE ${esquema}.caronas SET status='EM_ANDAMENTO' WHERE id_carona=9`,
    );
    const inicio = (
      await cliente.query(
        `SELECT iniciada_em FROM ${esquema}.caronas WHERE id_carona=9`,
      )
    ).rows[0].iniciada_em;
    assert.ok(inicio instanceof Date);
    await cliente.query(
      `UPDATE ${esquema}.caronas SET iniciada_em=NOW()+INTERVAL '1 day', status='EM_ANDAMENTO' WHERE id_carona=9`,
    );
    assert.equal(
      (
        await cliente.query(
          `SELECT iniciada_em FROM ${esquema}.caronas WHERE id_carona=9`,
        )
      ).rows[0].iniciada_em.getTime(),
      inicio.getTime(),
    );
    await cliente.query(
      `SELECT ${esquema}.encerrar_corridas_por_tempo((SELECT iniciada_em + INTERVAL '12 hours' - INTERVAL '1 millisecond' FROM ${esquema}.caronas WHERE id_carona=9))`,
    );
    assert.equal(
      (
        await cliente.query(
          `SELECT status FROM ${esquema}.caronas WHERE id_carona=9`,
        )
      ).rows[0].status,
      'EM_ANDAMENTO',
    );
    await cliente.query(
      `SELECT ${esquema}.encerrar_corridas_por_tempo((SELECT iniciada_em + INTERVAL '12 hours' FROM ${esquema}.caronas WHERE id_carona=9))`,
    );
    assert.equal(
      (
        await cliente.query(
          `SELECT status FROM ${esquema}.caronas WHERE id_carona=9`,
        )
      ).rows[0].status,
      'ENCERRADA_POR_TEMPO',
    );
    console.log(
      'PASSOU: 12h exatas, meia-noite/fuso, legado com margem, inicio imutavel, limpeza de GPS, pagamentos/reservas/pontos preservados e repeticao segura.',
    );
  } finally {
    await cliente.query('ROLLBACK');
    await cliente.end();
  }
}
executar().catch((erro) => {
  console.error('Teste do banco falhou:', erro.code ?? erro.name);
  if (erro.code === 'ERR_ASSERTION') console.error(erro.stack);
  process.exitCode = 1;
});
