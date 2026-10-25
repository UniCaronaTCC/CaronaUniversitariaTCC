// Teste opt-in: node -r ts-node/register test/veiculo-service-banco.ts
// Usa o .env local, sem iniciar AppModule/jobs; todas as fixtures sofrem rollback.
import 'reflect-metadata';
import 'dotenv/config';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { join } from 'node:path';
import { DataSource } from 'typeorm';
import { ConflictException } from '@nestjs/common';
import { UsersService } from '../src/users/users.service';
import { User } from '../src/users/user.entity';
import { Veiculo } from '../src/users/veiculo.entity';
import { Carona } from '../src/caronas/carona.entity';
import { InstituicoesService } from '../src/instituicoes/instituicoes.service';

async function executar() {
  const banco = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT ?? 5432),
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    schema: process.env.DB_SCHEMA ?? 'unicarona',
    ssl:
      process.env.DB_SSL === 'true'
        ? {
            rejectUnauthorized:
              process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
          }
        : false,
    entities: [join(__dirname, '../src/**/*.entity.ts').replaceAll('\\', '/')],
    synchronize: false,
    logging: false,
    connectTimeoutMS: 10000,
  });
  await banco.initialize();
  const runner = banco.createQueryRunner();
  try {
    await runner.startTransaction();
    const manager = runner.manager;
    const usuarios = manager.getRepository(User);
    const veiculos = manager.getRepository(Veiculo);
    const caronas = manager.getRepository(Carona);
    const service = new UsersService(
      usuarios,
      veiculos,
      {} as InstituicoesService,
    );
    const motorista = await usuarios.save(
      usuarios.create({
        nome: 'QA Veiculo Service',
        email: `${randomUUID()}@example.invalid`,
      }),
    );
    const passageiro = await usuarios.save(
      usuarios.create({
        nome: 'QA Veiculo Passageiro',
        email: `${randomUUID()}@example.invalid`,
      }),
    );
    const id = motorista.idUsuario;
    const placa = randomUUID().slice(0, 10);
    const salvar = (modelo: string) =>
      service.salvarVeiculo(id, modelo, 'Prata', placa);
    await salvar('Modelo A');
    assert.equal((await service.buscarVeiculo(id))?.modelo, 'Modelo A');

    const viagem = await caronas.save(
      caronas.create({
        origem: 'QA Encontro',
        destino: 'QA Campus',
        dataInicio: '2099-01-01',
        horario: '18:00:00',
        vagas: 3,
        valor: 5,
        usuario: motorista,
      }),
    );
    const snapshot = async () =>
      (await caronas.findOneByOrFail({ idCarona: viagem.idCarona }))
        .veiculoPublicado;
    assert.equal((await snapshot())?.modelo, 'Modelo A');
    await salvar('Modelo B');
    assert.equal((await snapshot())?.modelo, 'Modelo A');

    await manager.query(
      `INSERT INTO unicarona.solicitacoes(id_carona, id_passageiro, tipo_ponto_embarque, local_embarque, embarque_latitude, embarque_longitude)
       VALUES ($1, $2, 'NOVO', 'QA Encontro', -21, -50)`,
      [viagem.idCarona, passageiro.idUsuario],
    );
    await salvar('Modelo C'); // Pendente nao bloqueia.
    await manager.query(
      "UPDATE unicarona.solicitacoes SET status='ACEITA' WHERE id_carona=$1",
      [viagem.idCarona],
    );
    await assert.rejects(salvar('Modelo D'), ConflictException);
    assert.equal((await service.buscarVeiculo(id))?.modelo, 'Modelo C');
    await salvar('Modelo C'); // Mesmos dados continuam permitidos.

    await caronas.update(viagem.idCarona, { status: 'LOTADA' });
    await assert.rejects(salvar('Modelo D'), ConflictException);
    await caronas.update(viagem.idCarona, { dataInicio: '2000-01-01' });
    await salvar('Modelo D'); // Aceite de carona vencida nao bloqueia.
    await caronas.update(viagem.idCarona, { status: 'EM_ANDAMENTO' });
    await assert.rejects(salvar('Modelo E'), ConflictException); // Em andamento bloqueia mesmo antiga.
    await caronas.update(viagem.idCarona, { status: 'FINALIZADA' });
    await salvar('Modelo E');
    await caronas.update(viagem.idCarona, {
      dataInicio: '2099-01-01',
      status: 'CANCELADA',
    });
    await salvar('Modelo F');
    assert.equal((await snapshot())?.modelo, 'Modelo A');

    const nova = await caronas.save(
      caronas.create({
        origem: 'QA Encontro',
        destino: 'QA Campus',
        dataInicio: '2099-01-02',
        horario: '18:00:00',
        vagas: 3,
        valor: 5,
        usuario: motorista,
      }),
    );
    assert.equal(
      (await caronas.findOneByOrFail({ idCarona: nova.idCarona }))
        .veiculoPublicado?.modelo,
      'Modelo F',
    );
    // Passageiro nao pode bloquear a troca do proprio veiculo por carona alheia.
    await service.salvarVeiculo(
      passageiro.idUsuario,
      'Modelo Passageiro',
      'Preto',
      randomUUID().slice(0, 10),
    );
    console.log(
      'PASSOU: servico real, cadastro, troca, snapshot, pendente, aceite, lotada, idempotencia, vencida, em andamento, finalizada, cancelada, nova carona e isolamento de motorista',
    );
  } finally {
    if (runner.isTransactionActive) await runner.rollbackTransaction();
    await runner.release();
    await banco.destroy();
  }
}

void executar().catch((erro: unknown) => {
  console.error(
    erro instanceof Error
      ? `${erro.name}: ${erro.message}`
      : 'Falha no teste de integracao',
  );
  process.exitCode = 1;
});
