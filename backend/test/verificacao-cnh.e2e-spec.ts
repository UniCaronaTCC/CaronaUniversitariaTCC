import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';

import { SupabaseAuthService } from '../src/auth/supabase-auth.service';
import { UsersService } from '../src/users/users.service';
import { VerificacaoCnhController } from '../src/users/verificacao-cnh.controller';
import { VerificacaoCnhService } from '../src/users/verificacao-cnh.service';

describe('VerificacaoCnhController (HTTP)', () => {
  let app: INestApplication<App>;
  const verificar = jest.fn().mockResolvedValue({ status: 'APROVADA' });
  const reiniciarParaTeste = jest
    .fn()
    .mockResolvedValue({ status: 'NAO_ENVIADA' });

  beforeAll(async () => {
    const modulo = await Test.createTestingModule({
      controllers: [VerificacaoCnhController],
      providers: [
        {
          provide: VerificacaoCnhService,
          useValue: { verificar, reiniciarParaTeste },
        },
        {
          provide: SupabaseAuthService,
          useValue: {
            buscarUsuario: jest.fn((token: string) =>
              Promise.resolve(
                token === 'token-teste' ? { authId: 'conta-teste' } : null,
              ),
            ),
          },
        },
        {
          provide: UsersService,
          useValue: {
            buscarPorAuthId: jest.fn().mockResolvedValue({
              idUsuario: 42,
              email: 'teste@example.com',
              nome: 'Teste',
            }),
          },
        },
      ],
    }).compile();

    app = modulo.createNestApplication<App>();
    await app.init();
  });

  afterAll(async () => app.close());
  beforeEach(() => {
    verificar.mockClear();
    reiniciarParaTeste.mockClear();
  });

  it('ignora id fornecido pelo cliente no reset', async () => {
    await request(app.getHttpServer())
      .post('/usuarios/cnh/reiniciar-teste')
      .set('Authorization', 'Bearer token-teste')
      .send({ idUsuario: 1 })
      .expect(201);
    expect(reiniciarParaTeste).toHaveBeenCalledWith(42);
  });

  it.each([undefined, 'Basic token-teste', 'Bearer token-invalido'])(
    'bloqueia reset sem autenticacao valida: %s',
    async (authorization) => {
      const pedido = request(app.getHttpServer()).post(
        '/usuarios/cnh/reiniciar-teste',
      );
      if (authorization) pedido.set('Authorization', authorization);
      await pedido.send({ idUsuario: 42 }).expect(401);
      expect(reiniciarParaTeste).not.toHaveBeenCalled();
    },
  );

  it('recebe OCR em JSON sem arquivos e usa conta autenticada', async () => {
    const leitura = { largura: 1000, altura: 800, linhas: [] };
    await request(app.getHttpServer())
      .post('/usuarios/cnh/verificar-mlkit')
      .set('Authorization', 'Bearer token-teste')
      .send({
        versaoLeitura: 'mlkit-v1',
        aceitePrivacidade: true,
        nomeCompleto: 'Maria Silva',
        leitura,
        idUsuario: 1,
      })
      .expect(201);
    expect(verificar).toHaveBeenCalledWith(42, leitura, 'Maria Silva');
  });
  it('informa atualização para o contrato antigo', async () => {
    await request(app.getHttpServer())
      .post('/usuarios/cnh/verificar')
      .set('Authorization', 'Bearer token-teste')
      .field('aceitePrivacidade', 'true')
      .attach('frente', Buffer.from('foto'), 'foto.jpg')
      .expect(400);
    expect(verificar).not.toHaveBeenCalled();
  });
});
