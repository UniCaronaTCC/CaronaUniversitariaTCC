import { INestApplication, Logger } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Server } from 'node:http';
import request, { Response } from 'supertest';

import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { CaronasController } from '../caronas/caronas.controller';
import { CaronasService } from '../caronas/caronas.service';
import { SolicitacoesController } from '../solicitacoes/solicitacoes.controller';
import { SolicitacoesService } from '../solicitacoes/solicitacoes.service';
import { UsersService } from '../users/users.service';
import { Avaliacao } from './avaliacao.entity';
import { ReputacoesModule } from './reputacoes.module';

interface PessoaPublica {
  reputacao: { media: number; total: number } | null;
}

function lerDados<T>(resposta: Response): T {
  return (resposta.body as { dados: T }).dados;
}

describe('HTTP de reputacao nos cards (banco e autenticacao sinteticos)', () => {
  let app: INestApplication<Server>;
  const pessoa = (idUsuario: number) => ({
    idUsuario,
    nome: `Pessoa ${idUsuario}`,
    fotoPerfil: null,
    email: 'dado-privado@example.test',
    cpf: 'dado-privado',
  });
  const carona = (idCarona: number, idMotorista: number) => ({
    idCarona,
    usuario: pessoa(idMotorista),
    status: 'ATIVA',
    pontosEmbarque: [],
  });
  const solicitacao = (idSolicitacao: number, idPassageiro: number) => ({
    idSolicitacao,
    passageiro: pessoa(idPassageiro),
    carona: carona(1, 2),
    status: 'PENDENTE',
  });
  const caronas = {
    listarCaronas: jest.fn(),
    listarMinhasCaronas: jest.fn(),
    buscarDetalhesCarona: jest.fn(),
  };
  const solicitacoes = {
    listarRecebidas: jest.fn(),
    listarRecebidasDaCarona: jest.fn(),
    listarEnviadas: jest.fn(),
  };
  const consulta = {
    select: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    getRawMany: jest.fn(),
  };

  beforeAll(async () => {
    const modulo = await Test.createTestingModule({
      imports: [ReputacoesModule],
      controllers: [CaronasController, SolicitacoesController],
      providers: [
        { provide: CaronasService, useValue: caronas },
        { provide: SolicitacoesService, useValue: solicitacoes },
        {
          provide: SupabaseAuthService,
          useValue: {
            buscarUsuario: () => Promise.resolve({ authId: 'sintetico' }),
          },
        },
        {
          provide: UsersService,
          useValue: { buscarPorAuthId: () => Promise.resolve(pessoa(7)) },
        },
      ],
    })
      .overrideProvider(getRepositoryToken(Avaliacao))
      .useValue({ createQueryBuilder: () => consulta })
      .compile();
    app = modulo.createNestApplication<INestApplication<Server>>({
      logger: false,
    });
    await app.init();
  });
  afterAll(async () => app.close());
  beforeEach(() => {
    jest.clearAllMocks();
    const lista = [carona(1, 2), carona(2, 2), carona(3, 3)];
    caronas.listarCaronas.mockResolvedValue(lista);
    caronas.listarMinhasCaronas.mockResolvedValue(lista);
    caronas.buscarDetalhesCarona.mockResolvedValue(lista[0]);
    const pedidos = [solicitacao(10, 8), solicitacao(11, 9)];
    solicitacoes.listarRecebidas.mockResolvedValue(pedidos);
    solicitacoes.listarRecebidasDaCarona.mockResolvedValue(pedidos);
    solicitacoes.listarEnviadas.mockResolvedValue(pedidos);
    consulta.getRawMany.mockResolvedValue([]);
  });

  for (const rota of ['/caronas', '/caronas/minhas']) {
    it(`inclui o resumo do motorista em ${rota} sem uma consulta por card`, async () => {
      consulta.getRawMany.mockResolvedValue([
        { idUsuario: '2', media: '4.5', total: '2' },
      ]);
      const resposta = await request(app.getHttpServer())
        .get(rota)
        .set('Authorization', 'Bearer sintetico')
        .expect(200);
      const dados = lerDados<{ usuario: PessoaPublica }[]>(resposta);
      expect(dados.map((item) => item.usuario.reputacao)).toEqual([
        { media: 4.5, total: 2 },
        { media: 4.5, total: 2 },
        { media: 0, total: 0 },
      ]);
      expect(consulta.where).toHaveBeenCalledWith(expect.any(String), {
        idsUsuarios: [2, 3],
      });
      expect(consulta.getRawMany).toHaveBeenCalledTimes(1);
      expect(JSON.stringify(resposta.body)).not.toContain('privado');
    });
  }

  it('inclui o mesmo contrato nos detalhes da carona', async () => {
    consulta.getRawMany.mockResolvedValue([
      { idUsuario: '2', media: '5', total: '1' },
    ]);
    const resposta = await request(app.getHttpServer())
      .get('/caronas/1')
      .set('Authorization', 'Bearer sintetico')
      .expect(200);
    expect(
      lerDados<{ usuario: PessoaPublica }>(resposta).usuario.reputacao,
    ).toEqual({
      media: 5,
      total: 1,
    });
    expect(caronas.buscarDetalhesCarona).toHaveBeenCalledWith(1, 7);
  });

  for (const rota of ['/solicitacoes/recebidas', '/caronas/1/solicitacoes']) {
    it(`mostra a reputacao dos passageiros, nao a do motorista, em ${rota}`, async () => {
      consulta.getRawMany.mockResolvedValue([
        { idUsuario: '8', media: '3.75', total: '4' },
      ]);
      const resposta = await request(app.getHttpServer())
        .get(rota)
        .set('Authorization', 'Bearer sintetico')
        .expect(200);
      const dados = lerDados<{ passageiro: PessoaPublica }[]>(resposta);
      expect(dados[0].passageiro.reputacao).toEqual({
        media: 3.75,
        total: 4,
      });
      expect(dados[1].passageiro.reputacao).toEqual({
        media: 0,
        total: 0,
      });
      expect(consulta.where).toHaveBeenCalledWith(expect.any(String), {
        idsUsuarios: [8, 9],
      });
      expect(consulta.getRawMany).toHaveBeenCalledTimes(1);
      expect(JSON.stringify(resposta.body)).not.toContain('privado');
    });
  }

  it('mostra a reputacao do motorista nas enviadas', async () => {
    consulta.getRawMany.mockResolvedValue([
      { idUsuario: '2', media: '4.5', total: '2' },
    ]);
    const resposta = await request(app.getHttpServer())
      .get('/solicitacoes/enviadas')
      .set('Authorization', 'Bearer sintetico')
      .expect(200);
    expect(
      lerDados<{ motorista: PessoaPublica }[]>(resposta)[0].motorista.reputacao,
    ).toEqual({
      media: 4.5,
      total: 2,
    });
    expect(consulta.where).toHaveBeenCalledWith(expect.any(String), {
      idsUsuarios: [2],
    });
    expect(consulta.getRawMany).toHaveBeenCalledTimes(1);
  });

  it('nao impede listar caronas se o resumo estiver indisponivel', async () => {
    const aviso = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation(() => {});
    try {
      consulta.getRawMany.mockRejectedValue(new Error('indisponivel'));
      const resposta = await request(app.getHttpServer())
        .get('/caronas')
        .set('Authorization', 'Bearer sintetico')
        .expect(200);
      const dados = lerDados<{ usuario: PessoaPublica }[]>(resposta);
      expect(dados).toHaveLength(3);
      expect(dados[0].usuario.reputacao).toBeNull();
    } finally {
      aviso.mockRestore();
    }
  });

  it('nao consulta reputacao sem sessao', async () => {
    await request(app.getHttpServer()).get('/caronas').expect(401);
    expect(consulta.getRawMany).not.toHaveBeenCalled();
  });

  it('nao consulta o banco para lista vazia', async () => {
    caronas.listarCaronas.mockResolvedValue([]);
    const resposta = await request(app.getHttpServer())
      .get('/caronas')
      .set('Authorization', 'Bearer sintetico')
      .expect(200);
    expect(lerDados<unknown[]>(resposta)).toEqual([]);
    expect(consulta.getRawMany).not.toHaveBeenCalled();
  });
});
