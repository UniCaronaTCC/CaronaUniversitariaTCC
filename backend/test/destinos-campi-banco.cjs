// So usa banco explicitamente indicado para testes, em esquema descartavel.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');

async function testarDestinosCampi({ executar, consultar }) {
  const esquema = `qa_campi_${randomUUID().replaceAll('-', '')}`;
  const migracao = readFileSync(
    resolve(
      __dirname,
      '../../supabase/migrations/20261101202707_adicionar_metadados_destinos_campi.sql',
    ),
    'utf8',
  ).replaceAll('unicarona.', `${esquema}.`);
  const carga = readFileSync(
    resolve(
      __dirname,
      '../database/postgres/cargas/destinos_campi_aracatuba.sql',
    ),
    'utf8',
  ).replaceAll('unicarona.', `${esquema}.`);
  const alvos = [
    [4522, 'Araçatuba', '-21.235275', '-50.4060626'],
    [322, 'Araçatuba I', '-21.2230611', '-50.4251077'],
    [322, 'Araçatuba II', '-21.2073559', '-50.4506246'],
    [56, 'Araçatuba - Odontologia', '-21.2088278', '-50.4287895'],
    [56, 'Araçatuba - Veterinária', '-21.1838592', '-50.4370075'],
    [845, 'Araçatuba', null, null],
    [1418, 'Araçatuba', null, null],
    [15697, 'Araçatuba', null, null],
  ];
  const codigos = [
    ...new Set([...alvos.map(([codigo]) => codigo), 2289, 23215]),
  ];
  const ids = new Map();
  let cenarios = 0;

  const todos = async () =>
    (
      await consultar(`SELECT * FROM ${esquema}.instituicoes_campi
    ORDER BY id_campus`)
    ).rows;
  const toledo = async () =>
    (
      await consultar(`SELECT c.* FROM ${esquema}.instituicoes_campi c
    JOIN ${esquema}.instituicoes i USING (id_instituicao) WHERE i.codigo_emec=1418`)
    ).rows[0];
  const mudarToledo = (campos) =>
    executar(`UPDATE ${esquema}.instituicoes_campi SET ${campos}
    WHERE id_instituicao=(SELECT id_instituicao FROM ${esquema}.instituicoes WHERE codigo_emec=1418)`);

  async function preparar() {
    await executar('ROLLBACK;');
    await executar(
      `TRUNCATE ${esquema}.instituicoes_campi, ${esquema}.usuarios, ${esquema}.caronas;`,
    );
    for (const [codigo, nome, latitude, longitude] of alvos) {
      await consultar(
        `INSERT INTO ${esquema}.instituicoes_campi
        (id_instituicao,nome,municipio,uf,latitude,longitude) VALUES ($1,$2,'Araçatuba','SP',$3,$4)`,
        [ids.get(codigo), nome, latitude, longitude],
      );
    }
    for (const [codigo, cidade, uf] of [
      [2289, 'Araçatuba', 'SP'],
      [23215, 'Araçatuba', 'SP'],
      [4522, 'Birigui', 'SP'],
      [322, 'Araçatuba', 'MS'],
    ]) {
      await consultar(
        `INSERT INTO ${esquema}.instituicoes_campi
        (id_instituicao,nome,municipio,uf) VALUES ($1,'Araçatuba',$2,$3)`,
        [ids.get(codigo), cidade, uf],
      );
    }
    await executar(`INSERT INTO ${esquema}.usuarios VALUES (1,'Araçatuba');
      INSERT INTO ${esquema}.caronas VALUES (1,'Destino salvo',-21.235275,-50.4060626);`);
  }

  async function caso(nome, verificar) {
    await preparar();
    await verificar();
    cenarios++;
    console.log(`OK ${cenarios}: ${nome}`);
  }

  try {
    await executar(`CREATE SCHEMA ${esquema};
      CREATE TABLE ${esquema}.instituicoes (
        id_instituicao INTEGER GENERATED ALWAYS AS IDENTITY (START WITH 7000) PRIMARY KEY,
        codigo_emec INTEGER UNIQUE NOT NULL, ativa BOOLEAN NOT NULL DEFAULT TRUE);
      CREATE TABLE ${esquema}.instituicoes_campi (
        id_campus INTEGER GENERATED ALWAYS AS IDENTITY (START WITH 9000) PRIMARY KEY,
        id_instituicao INTEGER NOT NULL REFERENCES ${esquema}.instituicoes,
        nome VARCHAR(150) NOT NULL, municipio VARCHAR(100) NOT NULL, uf CHAR(2) NOT NULL,
        latitude NUMERIC(10,8), longitude NUMERIC(11,8), ativo BOOLEAN NOT NULL DEFAULT TRUE,
        UNIQUE (id_instituicao,nome,municipio,uf));
      CREATE TABLE ${esquema}.usuarios (id INTEGER, campus VARCHAR(150));
      CREATE TABLE ${esquema}.caronas (id INTEGER, destino TEXT, latitude NUMERIC, longitude NUMERIC);`);
    await executar(migracao);
    for (const codigo of codigos) {
      const resultado = await consultar(
        `INSERT INTO ${esquema}.instituicoes (codigo_emec)
        VALUES ($1) RETURNING id_instituicao`,
        [codigo],
      );
      ids.set(codigo, resultado.rows[0].id_instituicao);
    }

    await caso(
      'localiza oito unidades por eMEC e nome, sem depender de IDs gerados',
      async () => {
        await executar(carga);
        const preenchidos = (await todos()).filter(
          (c) => c.endereco_completo !== null,
        );
        assert.equal(preenchidos.length, 8);
        assert.ok(
          preenchidos.every((c) => c.id_campus >= 9000 && c.rotulo_unidade),
        );
        const unidade = await toledo();
        assert.equal(unidade.latitude, '-21.21307520');
        assert.equal(unidade.longitude, '-50.43053199');
        assert.ok(unidade.endereco_completo.includes('595'));
      },
    );
    await caso(
      'preserva identidades, nomes e todas as coordenadas antigas',
      async () => {
        const antes = await todos();
        await executar(carga);
        const depois = await todos();
        assert.equal(antes.length, depois.length);
        for (let i = 0; i < antes.length; i++) {
          for (const campo of [
            'id_campus',
            'id_instituicao',
            'nome',
            'municipio',
            'uf',
            'ativo',
          ]) {
            assert.deepEqual(depois[i][campo], antes[i][campo]);
          }
          if (antes[i].latitude !== null || antes[i].longitude !== null) {
            assert.equal(depois[i].latitude, antes[i].latitude);
            assert.equal(depois[i].longitude, antes[i].longitude);
          }
        }
      },
    );
    await caso(
      'nao modifica outras cidades, outra UF ou UCESP/ESP',
      async () => {
        const fora = (c) =>
          c.municipio !== 'Araçatuba' ||
          c.uf !== 'SP' ||
          [ids.get(2289), ids.get(23215)].includes(c.id_instituicao);
        const antes = (await todos()).filter(fora);
        await executar(carga);
        assert.deepEqual((await todos()).filter(fora), antes);
      },
    );
    await caso('nao altera perfis nem caronas', async () => {
      const usuarios = (await consultar(`SELECT * FROM ${esquema}.usuarios`))
        .rows;
      const caronas = (await consultar(`SELECT * FROM ${esquema}.caronas`))
        .rows;
      await executar(carga);
      assert.deepEqual(
        (await consultar(`SELECT * FROM ${esquema}.usuarios`)).rows,
        usuarios,
      );
      assert.deepEqual(
        (await consultar(`SELECT * FROM ${esquema}.caronas`)).rows,
        caronas,
      );
    });
    await caso(
      'reaplicacao nao duplica nem reescreve registros ja preenchidos',
      async () => {
        await executar(carga);
        const consulta = `SELECT id_campus,xmin::text AS versao FROM ${esquema}.instituicoes_campi ORDER BY id_campus`;
        const antes = (await consultar(consulta)).rows;
        await executar(carga);
        assert.deepEqual((await consultar(consulta)).rows, antes);
      },
    );
    await caso(
      'preserva ponto ja existente da UniToledo mesmo se diferente da fonte',
      async () => {
        await mudarToledo('latitude=-21.21,longitude=-50.43');
        await executar(carga);
        const campus = await toledo();
        assert.equal(campus.latitude, '-21.21000000');
        assert.equal(campus.longitude, '-50.43000000');
      },
    );
    await caso(
      'nao combina meia coordenada antiga com metade da nova',
      async () => {
        await mudarToledo('latitude=-21.21,longitude=NULL');
        await executar(carga);
        const campus = await toledo();
        assert.equal(campus.latitude, '-21.21000000');
        assert.equal(campus.longitude, null);
      },
    );
    await caso(
      'conflito de metadados cancela toda a carga sem sobrescrever',
      async () => {
        await mudarToledo(
          "endereco_completo='Endereco revisado por outra pessoa'",
        );
        const antes = await todos();
        await assert.rejects(executar(carga), /existem metadados diferentes/);
        await executar('ROLLBACK;');
        assert.deepEqual(await todos(), antes);
      },
    );
    await caso('campus inativo impede carga parcial', async () => {
      await mudarToledo('ativo=FALSE');
      const antes = await todos();
      await assert.rejects(
        executar(carga),
        /campus ausente, inativo ou ambiguo/,
      );
      await executar('ROLLBACK;');
      assert.deepEqual(await todos(), antes);
    });
    await caso('campus ausente impede carga parcial', async () => {
      await executar(`DELETE FROM ${esquema}.instituicoes_campi
        WHERE id_instituicao=(SELECT id_instituicao FROM ${esquema}.instituicoes WHERE codigo_emec=845)`);
      const antes = await todos();
      await assert.rejects(
        executar(carga),
        /campus ausente, inativo ou ambiguo/,
      );
      await executar('ROLLBACK;');
      assert.deepEqual(await todos(), antes);
    });
    await caso(
      'preenche metadados vazios sem inventar pontos para Fatec e FAC-FEA',
      async () => {
        await mudarToledo("rotulo_unidade='   ',endereco_completo='   '");
        await executar(carga);
        assert.equal((await toledo()).rotulo_unidade, 'Jardim Sumaré');
        const semPonto = (await todos()).filter((c) =>
          [ids.get(845), ids.get(15697)].includes(c.id_instituicao),
        );
        assert.ok(
          semPonto.every(
            (c) =>
              c.endereco_completo &&
              c.latitude === null &&
              c.longitude === null,
          ),
        );
      },
    );
    return cenarios;
  } finally {
    await executar('ROLLBACK;');
    await executar(`DROP SCHEMA IF EXISTS ${esquema} CASCADE;`);
  }
}

module.exports = { testarDestinosCampi };

if (require.main === module) {
  const { Client } = require('pg');
  async function main() {
    const url = process.env.CAMPI_TEST_DATABASE_URL;
    if (!url)
      throw new Error(
        'Informe CAMPI_TEST_DATABASE_URL de um banco isolado de testes. Nao usa o .env do aplicativo.',
      );
    const cliente = new Client({
      connectionString: url,
      connectionTimeoutMillis: 10000,
    });
    await cliente.connect();
    try {
      const cenarios = await testarDestinosCampi({
        executar: (sql) => cliente.query(sql),
        consultar: (sql, parametros) => cliente.query(sql, parametros),
      });
      console.log(`${cenarios} cenarios de carga aprovados.`);
    } finally {
      await cliente.end();
    }
  }
  main().catch((erro) => {
    console.error(erro.message);
    process.exitCode = 1;
  });
}
