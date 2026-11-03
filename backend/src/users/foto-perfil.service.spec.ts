import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { FotoPerfilService } from './foto-perfil.service';
import { createClient } from '@supabase/supabase-js';

jest.mock('@supabase/supabase-js', () => ({ createClient: jest.fn() }));

describe('FotoPerfilService', () => {
  it('avisa quando o Supabase não está configurado', async () => {
    const configService = {
      get: jest.fn().mockReturnValue(undefined),
    };
    const service = new FotoPerfilService(
      configService as unknown as ConfigService,
    );

    await expect(
      service.enviar(1, Buffer.from([0xff, 0xd8, 0xff]), 'image/jpeg'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  describe('arquivos do perfil', () => {
    const base =
      'https://storage.example.test/storage/v1/object/public/fotos-perfil/';
    const upload = jest.fn();
    const remove = jest.fn();
    const getPublicUrl = jest.fn((path: string) => ({
      data: { publicUrl: `${base}${path}` },
    }));
    const from = jest.fn();
    let service: FotoPerfilService;

    beforeEach(() => {
      jest.clearAllMocks();
      upload.mockResolvedValue({ error: null });
      remove.mockResolvedValue({ error: null, data: [] });
      from.mockReturnValue({ upload, remove, getPublicUrl });
      jest.mocked(createClient).mockReturnValue({ storage: { from } } as never);
      service = new FotoPerfilService({
        get: (key: string) =>
          ({
            SUPABASE_URL: 'https://storage.example.test',
            SUPABASE_SECRET_KEY: 'segredo-sintetico',
          })[key],
      } as unknown as ConfigService);
    });

    it('cada envio usa arquivo proprio sem sobrescrever fotos concorrentes', async () => {
      const primeira = await service.enviar(
        7,
        Buffer.from('foto'),
        'image/jpeg',
      );
      const segunda = await service.enviar(
        7,
        Buffer.from('foto'),
        'image/jpeg',
      );
      expect(primeira).not.toBe(segunda);
      expect(upload.mock.calls[0][0]).toMatch(
        /^usuarios\/7\/perfil-[0-9a-f-]{36}$/,
      );
      expect(upload.mock.calls[0][2]).toMatchObject({
        upsert: false,
        contentType: 'image/jpeg',
      });
      expect(from).toHaveBeenCalledWith('fotos-perfil');
    });

    it.each(['perfil', 'perfil-12345678-1234-1234-1234-123456789abc'])(
      'remove apenas o arquivo registrado, inclusive legado: %s',
      async (nome) => {
        await service.remover(7, `${base}usuarios/7/${nome}?v=123`);
        expect(remove).toHaveBeenCalledWith([`usuarios/7/${nome}`]);
      },
    );

    it.each([
      'https://outro.example.test/storage/v1/object/public/fotos-perfil/usuarios/7/perfil',
      `${base}usuarios/8/perfil`,
      `${base}usuarios/70/perfil`,
      `${base}usuarios/7/../../8/perfil`,
      `${base}usuarios/7/%2e%2e%2f8%2fperfil`,
      `${base}usuarios/7/perfil/outro`,
      `${base}usuarios/7/outro`,
      'nao-e-url',
    ])('nao exclui caminhos arbitrarios: %s', async (url) => {
      await expect(service.remover(7, url)).rejects.toThrow('identificar');
      expect(remove).not.toHaveBeenCalled();
    });

    it('falha do armazenamento nao e apresentada como exclusao concluida', async () => {
      remove.mockResolvedValue({ error: { message: 'falha sintetica' } });
      await expect(
        service.remover(7, `${base}usuarios/7/perfil`),
      ).rejects.toThrow('excluir');
    });

    it('erro de upload nao retorna uma URL inexistente', async () => {
      upload.mockResolvedValue({ error: { message: 'falha sintetica' } });
      const log = jest
        .spyOn(console, 'error')
        .mockImplementation(() => undefined);
      try {
        await expect(
          service.enviar(7, Buffer.from('foto'), 'image/jpeg'),
        ).rejects.toThrow('salvar');
        expect(getPublicUrl).not.toHaveBeenCalled();
      } finally {
        log.mockRestore();
      }
    });
  });
});
