import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

export interface UsuarioSupabase {
  authId: string;
  email: string;
}

@Injectable()
export class SupabaseAuthService {
  private readonly cliente: SupabaseClient | null;

  constructor(configService: ConfigService) {
    const url = configService.get<string>('SUPABASE_URL');
    const chave = configService.get<string>('SUPABASE_PUBLISHABLE_KEY');

    this.cliente =
      url && chave
        ? createClient(url, chave, {
            auth: {
              autoRefreshToken: false,
              persistSession: false,
            },
          })
        : null;
  }

  async buscarUsuario(token: string): Promise<UsuarioSupabase | null> {
    if (!this.cliente) {
      return null;
    }

    try {
      const { data, error } = await this.cliente.auth.getUser(token);
      const usuario = data.user;

      if (error) {
        const status = error.status;

        if (status === 0 || (status != null && status >= 500)) {
          throw new ServiceUnavailableException(
            'Serviço de autenticação temporariamente indisponível',
          );
        }

        return null;
      }

      if (!usuario?.email) {
        return null;
      }

      return {
        authId: usuario.id,
        email: usuario.email,
      };
    } catch (erro) {
      if (erro instanceof ServiceUnavailableException) {
        throw erro;
      }

      throw new ServiceUnavailableException(
        'Serviço de autenticação temporariamente indisponível',
      );
    }
  }
}
