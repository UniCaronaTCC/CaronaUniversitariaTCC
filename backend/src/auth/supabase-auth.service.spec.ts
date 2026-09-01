import { ConfigService } from '@nestjs/config';
import { createClient } from '@supabase/supabase-js';

import { SupabaseAuthService } from './supabase-auth.service';

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(),
}));

describe('SupabaseAuthService', () => {
  const getUser = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();

    (createClient as jest.Mock).mockReturnValue({
      auth: { getUser },
    });
  });

  function criarService(configurado = true) {
    const configService = {
      get: jest.fn((chave: string) => {
        if (!configurado) return undefined;
        if (chave === 'SUPABASE_URL') return 'https://teste.supabase.co';
        if (chave === 'SUPABASE_PUBLISHABLE_KEY') return 'chave-publica';
        return undefined;
      }),
    };

    return new SupabaseAuthService(configService as unknown as ConfigService);
  }

  it('retorna o usuário de um token válido', async () => {
    getUser.mockResolvedValue({
      data: {
        user: {
          id: 'uuid-do-supabase',
          email: 'joao@email.com',
        },
      },
      error: null,
    });

    const resultado = await criarService().buscarUsuario('token-valido');

    expect(getUser).toHaveBeenCalledWith('token-valido');
    expect(resultado).toEqual({
      authId: 'uuid-do-supabase',
      email: 'joao@email.com',
    });
  });

  it('recusa token inválido', async () => {
    getUser.mockResolvedValue({
      data: { user: null },
      error: { message: 'token inválido' },
    });

    await expect(
      criarService().buscarUsuario('token-invalido'),
    ).resolves.toBeNull();
  });

  it('mantém o login antigo quando o Supabase não está configurado', async () => {
    await expect(
      criarService(false).buscarUsuario('token'),
    ).resolves.toBeNull();

    expect(createClient).not.toHaveBeenCalled();
  });
});
