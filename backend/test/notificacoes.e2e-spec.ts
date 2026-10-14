import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { Server } from 'node:http';
import { JwtAuthGuard } from '../src/auth/jwt-auth.guard';
import { NotificacoesController } from '../src/notificacoes/notificacoes.controller';
import { NotificacoesService } from '../src/notificacoes/notificacoes.service';

describe('Notificacoes HTTP', () => {
  let app: INestApplication;
  const service = { contar: jest.fn(), listar: jest.fn(), abrir: jest.fn() };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [NotificacoesController],
      providers: [{ provide: NotificacoesService, useValue: service }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context: {
          switchToHttp: () => {
            getRequest: () => {
              headers: Record<string, string>;
              usuario?: { sub: number };
            };
          };
        }) => {
          const req = context.switchToHttp().getRequest();
          if (req.headers.authorization !== 'Bearer sintetico') return false;
          req.usuario = { sub: 7 };
          return true;
        },
      })
      .compile();
    app = module.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());
  beforeEach(() => {
    jest.resetAllMocks();
    service.contar.mockResolvedValue(2);
    service.listar.mockResolvedValue({
      itens: [],
      totalNaoLidas: 2,
      temMais: false,
    });
    service.abrir.mockResolvedValue({
      itens: [],
      totalNaoLidas: 0,
      temMais: false,
    });
  });

  it('nao permite acesso sem autenticacao', async () => {
    await request(app.getHttpServer() as Server)
      .get('/notificacoes')
      .expect(403);
    await request(app.getHttpServer() as Server)
      .post('/notificacoes/abrir')
      .expect(403);
    expect(service.listar).not.toHaveBeenCalled();
    expect(service.abrir).not.toHaveBeenCalled();
  });

  it('abrir ignora usuario enviado no corpo e marca automaticamente', async () => {
    await request(app.getHttpServer() as Server)
      .post('/notificacoes/abrir')
      .set('Authorization', 'Bearer sintetico')
      .send({ idUsuario: 99 })
      .expect(201);
    expect(service.abrir).toHaveBeenCalledWith(7);
  });

  it('consultar contador ou pagina nao marca notificacoes', async () => {
    await request(app.getHttpServer() as Server)
      .get('/notificacoes/nao-lidas?idUsuario=99')
      .set('Authorization', 'Bearer sintetico')
      .expect(200);
    await request(app.getHttpServer() as Server)
      .get('/notificacoes?antesDe=30&idUsuario=99')
      .set('Authorization', 'Bearer sintetico')
      .expect(200);
    expect(service.contar).toHaveBeenCalledWith(7);
    expect(service.listar).toHaveBeenCalledWith(7, 30);
    expect(service.abrir).not.toHaveBeenCalled();
  });

  for (const cursor of ['0', '-1', '1.5', 'abc', '2147483648', '1 OR 1=1']) {
    it(`rejeita cursor invalido ${cursor}`, async () => {
      await request(app.getHttpServer() as Server)
        .get(`/notificacoes?antesDe=${encodeURIComponent(cursor)}`)
        .set('Authorization', 'Bearer sintetico')
        .expect(400);
      expect(service.listar).not.toHaveBeenCalled();
    });
  }
});
