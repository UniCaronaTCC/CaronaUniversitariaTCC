const assert = require('node:assert/strict');
const path = require('node:path');
require('dotenv').config({
  path: path.join(__dirname, '..', '.env'),
  quiet: true,
});
require('ts-node/register/transpile-only');
const { ConfigService } = require('@nestjs/config');
const { createClient } = require('@supabase/supabase-js');
const { DataSource } = require('typeorm');
const { User } = require('../src/users/user.entity');
const { Veiculo } = require('../src/users/veiculo.entity');
const { UsersService } = require('../src/users/users.service');
const { UsersController } = require('../src/users/users.controller');
const { FotoPerfilService } = require('../src/users/foto-perfil.service');

// Opt-in: somente usuario sintetico em rollback e arquivos da pasta QA vazia.
async function main() {
  assert(
    process.argv.includes('--executar'),
    'Use --executar para autorizar o teste remoto sintetico.',
  );
  assert.equal(
    new URL(process.env.SUPABASE_URL).hostname,
    'kytkkjvzhvwjqzyaujak.supabase.co',
  );
  const id = 2147483000;
  const pasta = `usuarios/${id}`;
  const bucket = process.env.SUPABASE_PROFILE_BUCKET || 'fotos-perfil';
  const admin = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SECRET_KEY,
    {
      auth: { autoRefreshToken: false, persistSession: false },
      global: {
        fetch: (input, init) =>
          fetch(input, { ...init, signal: AbortSignal.timeout(15000) }),
      },
    },
  );
  const publico = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY,
    {
      auth: { autoRefreshToken: false, persistSession: false },
      global: {
        fetch: (input, init) =>
          fetch(input, { ...init, signal: AbortSignal.timeout(15000) }),
      },
    },
  );
  const storage = admin.storage.from(bucket);
  const inicial = await storage.list(pasta);
  assert.ifError(inicial.error);
  assert.equal(
    inicial.data.length,
    0,
    'Pasta QA nao esta vazia; teste cancelado sem excluir arquivos.',
  );
  const schema = process.env.DB_SCHEMA || 'unicarona';
  assert(/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(schema));
  const banco = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    schema,
    entities: [User, Veiculo],
    synchronize: false,
    ssl:
      process.env.DB_SSL === 'true'
        ? {
            rejectUnauthorized:
              process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
          }
        : false,
    extra: { connectionTimeoutMillis: 15000, max: 2 },
  });
  const arquivos = new Set();
  const nomes = (url) => {
    const caminho = decodeURIComponent(new URL(url).pathname);
    const inicio = caminho.indexOf(`/${pasta}/`);
    assert(inicio >= 0);
    return caminho.slice(inicio + 1);
  };
  const png = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/6S8AAAAASUVORK5CYII=',
    'base64',
  );
  let runner;
  const resultados = [];
  try {
    await banco.initialize();
    assert.equal(
      (
        await banco.query(
          `select count(*)::int as total from "${schema}".usuarios where id_usuario=$1`,
          [id],
        )
      )[0].total,
      0,
      'ID QA em uso.',
    );
    runner = banco.createQueryRunner();
    await runner.connect();
    await runner.startTransaction();
    await runner.query(
      `insert into "${schema}".usuarios (id_usuario,nome,email,status_verificacao_cnh,cpf,cnh_categoria,cnh_validade,cnh_verificada_em,privacidade_aceita_em)
      values ($1,'QA Foto Perfil','qa-foto-2147483000@example.invalid','APROVADA','00000000000','AB','2099-05-01',now(),now())`,
      [id],
    );
    const usuarios = new UsersService(
      runner.manager.getRepository(User),
      runner.manager.getRepository(Veiculo),
      {},
    );
    const fotos = new FotoPerfilService(new ConfigService(process.env));
    const controller = new UsersController(usuarios, fotos);
    const req = { usuario: { sub: id } };
    const enviar = async () => {
      // Registra o caminho antes da gravacao no banco para limpar mesmo se ela falhar.
      const original = fotos.enviar.bind(fotos);
      fotos.enviar = async (...args) => {
        const url = await original(...args);
        arquivos.add(nomes(url));
        return url;
      };
      try {
        return await controller.atualizarFotoPerfil({ buffer: png }, req);
      } finally {
        fotos.enviar = original;
      }
    };
    const primeira = await enviar();
    const url1 = primeira.dados.fotoPerfil;
    assert.equal(primeira.dados.statusVerificacaoCnh, 'APROVADA');
    assert.equal((await usuarios.buscarPorId(id)).fotoPerfil, url1);
    const baixada = await fetch(url1, { signal: AbortSignal.timeout(15000) });
    assert.equal(baixada.status, 200);
    assert(Buffer.from(await baixada.arrayBuffer()).equals(png));
    resultados.push(
      'upload PNG real, leitura publica e persistencia pelo servico',
    );

    const apagamentoAnonimo = await publico.storage
      .from(bucket)
      .remove([nomes(url1)]);
    assert(apagamentoAnonimo.error || apagamentoAnonimo.data?.length === 0);
    const aindaExiste = await storage.list(pasta);
    assert.ifError(aindaExiste.error);
    assert(
      aindaExiste.data.some(
        (arquivo) => arquivo.name === path.posix.basename(nomes(url1)),
      ),
    );
    resultados.push('cliente publico nao consegue excluir a foto');

    await assert.rejects(fotos.remover(id - 1, url1));
    resultados.push('servico nao exclui arquivo de outra conta');

    const segunda = await enviar();
    const url2 = segunda.dados.fotoPerfil;
    assert.notEqual(url1, url2);
    assert.equal(segunda.aviso, undefined);
    const aposTroca = await storage.list(pasta);
    assert.ifError(aposTroca.error);
    assert.equal(aposTroca.data.length, 1);
    assert.equal(aposTroca.data[0].name, path.posix.basename(nomes(url2)));
    resultados.push('troca usa arquivo novo e exclui o antigo');

    await assert.rejects(
      controller.removerFotoPerfil({ fotoAtual: url1 }, req),
      /outro acesso/,
    );
    assert.equal((await usuarios.buscarPorId(id)).fotoPerfil, url2);
    resultados.push('remocao atrasada preserva foto atual');

    const snapshot = await usuarios.buscarPorId(id);
    const removida = await controller.removerFotoPerfil(
      { fotoAtual: url2, idUsuario: 1 },
      req,
    );
    assert.equal(removida.dados.fotoPerfil, null);
    assert.equal(removida.aviso, undefined);
    const depois = await usuarios.buscarPorId(id);
    assert.deepEqual({ ...depois }, { ...snapshot, fotoPerfil: null });
    assert.equal((await storage.list(pasta)).data.length, 0);
    resultados.push(
      'DELETE limpa banco e Storage preservando CNH e demais dados',
    );

    assert.equal(
      (await controller.removerFotoPerfil({ fotoAtual: url2 }, req)).dados
        .fotoPerfil,
      null,
    );
    resultados.push('repetir remocao e seguro');

    const legado = `${pasta}/perfil`;
    arquivos.add(legado);
    assert.ifError(
      (
        await storage.upload(legado, png, {
          contentType: 'image/png',
          upsert: false,
        })
      ).error,
    );
    const urlLegado = `${storage.getPublicUrl(legado).data.publicUrl}?v=1`;
    await usuarios.atualizarFotoPerfil(
      await usuarios.buscarPorId(id),
      urlLegado,
    );
    assert.equal(
      (await controller.removerFotoPerfil({ fotoAtual: urlLegado }, req)).dados
        .fotoPerfil,
      null,
    );
    resultados.push('foto antiga com caminho fixo tambem pode ser removida');

    await runner.rollbackTransaction();
    assert.equal(
      (
        await banco.query(
          `select count(*)::int as total from "${schema}".usuarios where id_usuario=$1`,
          [id],
        )
      )[0].total,
      0,
    );
    resultados.push(
      'rollback remove todos os dados sinteticos sem alterar contas reais',
    );
  } finally {
    if (runner?.isTransactionActive) await runner.rollbackTransaction();
    if (runner) await runner.release();
    if (banco.isInitialized) await banco.destroy();
    if (arquivos.size)
      assert.ifError((await storage.remove([...arquivos])).error);
    const final = await storage.list(pasta);
    assert.ifError(final.error);
    assert.equal(final.data.length, 0, 'Arquivos QA permaneceram no Storage.');
  }
  console.log(
    JSON.stringify(
      {
        testes: resultados.length,
        resultados,
        pastaQaVazia: true,
        usuarioSinteticoPersistido: false,
      },
      null,
      2,
    ),
  );
}
main().catch((erro) => {
  console.error(`QA foto: ${erro.name}: ${erro.message}`);
  process.exitCode = 1;
});
