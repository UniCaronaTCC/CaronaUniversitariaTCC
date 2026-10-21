import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';
import { SupabaseAuthService } from '../auth/supabase-auth.service';
import { UsersService } from '../users/users.service';
import { Carona } from './carona.entity';
import { CaronasController } from './caronas.controller';
import { CaronasService } from './caronas.service';
import { RecorrenciaCarona } from './recorrencia.entity';
import { RecorrenciasController } from './recorrencias.controller';
import { RecorrenciasService } from './recorrencias.service';

describe('HTTP de publicacao por encontro (sem banco real)', () => {
  let app: INestApplication<Server>;
  const caronas = {
    criarCarona: jest.fn<
      ReturnType<CaronasService['criarCarona']>,
      Parameters<CaronasService['criarCarona']>
    >(),
    atualizarCarona: jest.fn<
      ReturnType<CaronasService['atualizarCarona']>,
      Parameters<CaronasService['atualizarCarona']>
    >(),
  };
  const recorrencias = {
    atualizar: jest.fn<
      ReturnType<RecorrenciasService['atualizar']>,
      Parameters<RecorrenciasService['atualizar']>
    >(),
  };
  const ponto = { endereco: 'Rua A, 10', latitude: -21.2, longitude: -50.4 };
  const body = {
    destino: 'Campus',
    destinoLatitude: -21.1,
    destinoLongitude: -50.3,
    dataInicio: '2099-12-01',
    horario: '18:00:00',
    vagas: 3,
    valor: 5,
    recorrente: false,
    pontosEmbarque: [ponto],
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [CaronasController, RecorrenciasController],
      providers: [
        { provide: CaronasService, useValue: caronas },
        { provide: RecorrenciasService, useValue: recorrencias },
        {
          provide: SupabaseAuthService,
          useValue: {
            buscarUsuario: () => Promise.resolve({ authId: 'sintetico' }),
          },
        },
        {
          provide: UsersService,
          useValue: {
            buscarPorAuthId: () =>
              Promise.resolve({
                idUsuario: 7,
                email: 'teste@example.com',
                nome: 'Teste',
              }),
          },
        },
      ],
    }).compile();
    app = module.createNestApplication<INestApplication<Server>>({
      logger: false,
    });
    await app.init();
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => {
    jest.clearAllMocks();
    caronas.criarCarona.mockImplementation((dados) =>
      Promise.resolve(
        Object.assign(new Carona(), dados, {
          idCarona: 10,
          usuario: { idUsuario: 7, nome: 'Teste', veiculo: null },
          pontosEmbarque: [],
        }),
      ),
    );
    recorrencias.atualizar.mockImplementation((_id, _usuario, dados) => {
      const modelo = new RecorrenciaCarona();
      modelo.idRecorrencia = 20;
      modelo.definirDados(dados!);
      return Promise.resolve(modelo);
    });
  });

  it('POST sem origem publica a partir do encontro autenticando o motorista', async () => {
    await request(app.getHttpServer())
      .post('/caronas')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, idUsuario: 99 })
      .expect(201);
    expect(caronas.criarCarona).toHaveBeenCalledWith(
      expect.objectContaining({
        idUsuario: 7,
        origem: ponto.endereco,
        origemLatitude: ponto.latitude,
        origemLongitude: ponto.longitude,
      }),
    );
  });
  it('POST sem ponto e rejeitado antes de salvar', async () => {
    await request(app.getHttpServer())
      .post('/caronas')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, pontosEmbarque: [] })
      .expect(400);
    expect(caronas.criarCarona).not.toHaveBeenCalled();
  });
  it('POST com coordenada invalida e rejeitado antes de salvar', async () => {
    await request(app.getHttpServer())
      .post('/caronas')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, pontosEmbarque: [{ ...ponto, latitude: 100 }] })
      .expect(400);
    expect(caronas.criarCarona).not.toHaveBeenCalled();
  });
  it('POST com pontos duplicados e rejeitado antes de salvar', async () => {
    await request(app.getHttpServer())
      .post('/caronas')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, pontosEmbarque: [ponto, ponto] })
      .expect(400);
    expect(caronas.criarCarona).not.toHaveBeenCalled();
  });
  it('POST continua exigindo autenticacao', async () => {
    await request(app.getHttpServer()).post('/caronas').send(body).expect(401);
    expect(caronas.criarCarona).not.toHaveBeenCalled();
  });
  it('PATCH da programacao usa o encontro para suas novas datas', async () => {
    await request(app.getHttpServer())
      .patch('/recorrencias/20')
      .set('Authorization', 'Bearer sintetico')
      .send({ ...body, recorrente: true, diasSemana: ['SEG'] })
      .expect(200);
    expect(recorrencias.atualizar).toHaveBeenCalledWith(
      20,
      7,
      expect.objectContaining({
        origem: ponto.endereco,
        origemLatitude: ponto.latitude,
        origemLongitude: ponto.longitude,
      }),
    );
  });
});
