import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { FotoPerfilService } from './foto-perfil.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('Foto de perfil HTTP', () => {
  let app: INestApplication;
  const foto = 'https://storage.example.test/usuarios/7/perfil';
  const usuarios = {
    buscarPorId: jest.fn(),
    atualizarFotoPerfil: jest.fn(),
    buscarVeiculo: jest.fn(),
  };
  const arquivos = { remover: jest.fn(), enviar: jest.fn() };

  beforeAll(async () => {
    const modulo = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        { provide: UsersService, useValue: usuarios },
        { provide: FotoPerfilService, useValue: arquivos },
      ],
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
    app = modulo.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());
  beforeEach(() => {
    jest.resetAllMocks();
    usuarios.buscarPorId.mockResolvedValue({ idUsuario: 7, fotoPerfil: foto });
    usuarios.atualizarFotoPerfil.mockImplementation(
      async (usuario, fotoPerfil) => ({ ...usuario, fotoPerfil }),
    );
    usuarios.buscarVeiculo.mockResolvedValue(null);
    arquivos.remover.mockResolvedValue(undefined);
    arquivos.enviar.mockResolvedValue('https://storage.example.test/nova');
  });

  it.each(['delete', 'patch'] as const)(
    'bloqueia %s sem autenticacao',
    async (metodo) => {
      await request(app.getHttpServer())
        [metodo]('/usuarios/perfil/foto')
        .send({ fotoAtual: foto })
        .expect(403);
      expect(usuarios.buscarPorId).not.toHaveBeenCalled();
      expect(arquivos.remover).not.toHaveBeenCalled();
    },
  );
  it('DELETE usa exclusivamente a conta autenticada e retorna 200 com perfil', async () => {
    const resposta = await request(app.getHttpServer())
      .delete('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .send({ fotoAtual: foto, idUsuario: 99 })
      .expect(200);
    expect(resposta.body.dados).toMatchObject({ id: 7, fotoPerfil: null });
    expect(arquivos.remover).toHaveBeenCalledWith(7, foto);
  });
  it('DELETE sem fotoAtual retorna erro controlado e nao grava', async () => {
    await request(app.getHttpServer())
      .delete('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .send({})
      .expect(400);
    expect(usuarios.atualizarFotoPerfil).not.toHaveBeenCalled();
  });
  it('DELETE de foto antiga retorna conflito e nao exclui foto atual', async () => {
    await request(app.getHttpServer())
      .delete('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .send({ fotoAtual: `${foto}-antiga` })
      .expect(409);
    expect(arquivos.remover).not.toHaveBeenCalled();
  });
  it('PATCH multipart continua aceitando imagem permitida', async () => {
    await request(app.getHttpServer())
      .patch('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .attach('foto', Buffer.from([0xff, 0xd8, 0xff, 0]), 'foto.jpg')
      .expect(200);
    expect(arquivos.enviar).toHaveBeenCalledWith(
      7,
      expect.any(Buffer),
      'image/jpeg',
    );
    expect(arquivos.remover).toHaveBeenCalledWith(7, foto);
  });
  it('PATCH multipart recusa arquivo invalido e nao toca no armazenamento', async () => {
    await request(app.getHttpServer())
      .patch('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .attach('foto', Buffer.from('invalido'), 'foto.jpg')
      .expect(400);
    expect(arquivos.enviar).not.toHaveBeenCalled();
  });

  it('PATCH sem arquivo retorna erro controlado', async () => {
    await request(app.getHttpServer())
      .patch('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .send({})
      .expect(400);
    expect(arquivos.enviar).not.toHaveBeenCalled();
  });

  it('PATCH acima de 5 MB e recusado antes do armazenamento', async () => {
    await request(app.getHttpServer())
      .patch('/usuarios/perfil/foto')
      .set('Authorization', 'Bearer sintetico')
      .attach('foto', Buffer.alloc(5 * 1024 * 1024 + 1), 'grande.jpg')
      .expect(413);
    expect(arquivos.enviar).not.toHaveBeenCalled();
  });
});
