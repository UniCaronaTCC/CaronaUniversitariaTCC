import {
  Injectable,
  InternalServerErrorException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { randomUUID } from 'node:crypto';

interface BancoSupabase {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}

@Injectable()
export class FotoPerfilService {
  private readonly url: string | undefined;
  private readonly chave: string | undefined;
  private readonly bucket: string;

  constructor(configService: ConfigService) {
    this.url = configService.get<string>('SUPABASE_URL');
    this.chave = configService.get<string>('SUPABASE_SECRET_KEY');

    this.bucket =
      configService.get<string>('SUPABASE_PROFILE_BUCKET') ?? 'fotos-perfil';
  }

  async enviar(
    idUsuario: number,
    arquivo: Buffer,
    tipoArquivo: string,
  ): Promise<string> {
    const supabase = this.criarCliente();

    const caminho = `usuarios/${idUsuario}/perfil-${randomUUID()}`;
    const { error } = await supabase.storage
      .from(this.bucket)
      .upload(caminho, arquivo, {
        contentType: tipoArquivo,
        cacheControl: '3600',
        upsert: false,
      });

    if (error) {
      console.error('Erro ao salvar foto de perfil:', error.message);
      throw new InternalServerErrorException(
        'Não foi possível salvar a foto de perfil',
      );
    }

    const { data } = supabase.storage.from(this.bucket).getPublicUrl(caminho);

    return `${data.publicUrl}?v=${Date.now()}`;
  }

  async remover(idUsuario: number, urlFoto: string): Promise<void> {
    const supabase = this.criarCliente();
    const prefixo = `usuarios/${idUsuario}/`;
    const { data } = supabase.storage.from(this.bucket).getPublicUrl(prefixo);
    let caminho: string;
    try {
      const base = new URL(data.publicUrl);
      const foto = new URL(urlFoto);
      if (
        foto.origin !== base.origin ||
        !foto.pathname.startsWith(base.pathname)
      ) {
        throw new Error('Caminho fora do perfil');
      }
      const nome = decodeURIComponent(
        foto.pathname.slice(base.pathname.length),
      );
      if (
        !/^perfil(?:-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})?$/.test(
          nome,
        )
      ) {
        throw new Error('Nome de arquivo invalido');
      }
      caminho = `${prefixo}${nome}`;
    } catch {
      throw new InternalServerErrorException(
        'Não foi possível identificar a foto para exclusão',
      );
    }
    const { error } = await supabase.storage
      .from(this.bucket)
      .remove([caminho]);
    if (error) {
      throw new InternalServerErrorException(
        'Não foi possível excluir o arquivo da foto',
      );
    }
  }

  private criarCliente(): SupabaseClient<BancoSupabase> {
    if (!this.url || !this.chave) {
      throw new ServiceUnavailableException(
        'Armazenamento de fotos não configurado',
      );
    }

    try {
      const cliente = createClient<BancoSupabase>(this.url, this.chave, {
        global: {
          fetch: (input, init) =>
            fetch(input, {
              ...init,
              signal: AbortSignal.any([
                AbortSignal.timeout(15000),
                ...(init?.signal ? [init.signal] : []),
              ]),
            }),
        },
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      });

      return cliente;
    } catch {
      throw new ServiceUnavailableException(
        'Configuração do armazenamento de fotos inválida',
      );
    }
  }
}
