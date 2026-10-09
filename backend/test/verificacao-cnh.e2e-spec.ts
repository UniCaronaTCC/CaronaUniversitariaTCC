import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import sharp from 'sharp';
import request from 'supertest';
import { App } from 'supertest/types';

import { JwtAuthGuard } from '../src/auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../src/auth/requisicao-com-usuario';
import { VerificacaoCnhController } from '../src/users/verificacao-cnh.controller';
import { VerificacaoCnhService } from '../src/users/verificacao-cnh.service';

describe('VerificacaoCnhController (HTTP)', () => {
  let app: INestApplication<App>;
  const recebidos: Array<{ idUsuario: number; frente: Buffer; verso: Buffer }> =
    [];
  const verificar = jest.fn(
    (idUsuario: number, frente: Buffer, verso: Buffer) => {
      recebidos.push({
        idUsuario,
        frente: Buffer.from(frente),
        verso: Buffer.from(verso),
      });
      return Promise.resolve({ status: 'APROVADA' });
    },
  );

  beforeAll(async () => {
    const modulo = await Test.createTestingModule({
      controllers: [VerificacaoCnhController],
      providers: [{ provide: VerificacaoCnhService, useValue: { verificar } }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (contexto: {
          switchToHttp: () => {
            getRequest: () => RequisicaoComUsuario;
          };
        }) => {
          contexto.switchToHttp().getRequest().usuario = {
            sub: 42,
            email: 'teste@example.com',
            nome: 'Teste',
          };
          return true;
        },
      })
      .compile();

    app = modulo.createNestApplication<App>();
    await app.init();
  });

  afterAll(async () => app.close());
  beforeEach(() => {
    verificar.mockClear();
    recebidos.length = 0;
  });

  it('recebe duas fotos e o aceite sem persistir arquivos', async () => {
    const foto = await sharp({
      create: {
        width: 900,
        height: 600,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();

    await request(app.getHttpServer())
      .post('/usuarios/cnh/verificar')
      .field('aceitePrivacidade', 'true')
      .field('nomeCompleto', 'João Pedro da Silva')
      .attach('frente', foto, 'frente.png')
      .attach('verso', foto, 'verso.png')
      .expect(201)
      .expect(({ body }: { body: { dados: { status: string } } }) => {
        expect(body.dados.status).toBe('APROVADA');
      });

    expect(verificar).toHaveBeenCalledTimes(1);
    expect(recebidos).toEqual([{ idUsuario: 42, frente: foto, verso: foto }]);
  });
});
