import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Server } from 'node:http';
import request from 'supertest';

import { InstituicoesController } from './instituicoes.controller';
import { InstituicoesService } from './instituicoes.service';

describe('HTTP de destinos (sem AppModule e sem banco real)', () => {
  let app: INestApplication<Server>;
  const service = {
    listarDestinos: jest.fn().mockResolvedValue([{ idCampus: 10 }]),
    buscar: jest.fn().mockResolvedValue([]),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [InstituicoesController],
      providers: [{ provide: InstituicoesService, useValue: service }],
    }).compile();
    app = module.createNestApplication<INestApplication<Server>>({
      logger: false,
    });
    await app.init();
  });
  afterAll(async () => {
    await app.close();
  });
  beforeEach(() => jest.clearAllMocks());

  it('GET /instituicoes/destinos funciona sem busca', async () => {
    await request(app.getHttpServer())
      .get('/instituicoes/destinos')
      .query({ cidade: 'Araçatuba', uf: 'sp' })
      .expect(200)
      .expect({ sucesso: true, dados: [{ idCampus: 10 }] });
    expect(service.listarDestinos).toHaveBeenCalledWith('Araçatuba', 'SP');
  });
  it('não permite consulta nacional ilimitada sem cidade e UF', async () => {
    await request(app.getHttpServer())
      .get('/instituicoes/destinos')
      .expect(400);
    expect(service.listarDestinos).not.toHaveBeenCalled();
  });
  it('parâmetros repetidos não geram 500', async () => {
    await request(app.getHttpServer())
      .get('/instituicoes/destinos?cidade=A&cidade=B&uf=SP')
      .expect(400);
  });
  it('rota de cadastro mantém sua validação de duas letras', async () => {
    await request(app.getHttpServer()).get('/instituicoes?busca=u').expect(400);
    await request(app.getHttpServer())
      .get('/instituicoes?busca=un')
      .expect(200)
      .expect({ sucesso: true, dados: [] });
    expect(service.buscar).toHaveBeenCalledTimes(1);
  });
});
