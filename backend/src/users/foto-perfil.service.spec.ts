import { ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { FotoPerfilService } from './foto-perfil.service';

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
});
