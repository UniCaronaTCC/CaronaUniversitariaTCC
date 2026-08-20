import {
  Injectable,
  InternalServerErrorException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

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

    const caminho = `usuarios/${idUsuario}/perfil`;
    const { error } = await supabase.storage
      .from(this.bucket)
      .upload(caminho, arquivo, {
        contentType: tipoArquivo,
        cacheControl: '3600',
        upsert: true,
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

  private criarCliente(): SupabaseClient {
    if (!this.url || !this.chave) {
      throw new ServiceUnavailableException(
        'Armazenamento de fotos não configurado',
      );
    }

    try {
      return createClient(this.url, this.chave, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      });
    } catch {
      throw new ServiceUnavailableException(
        'Configuração do armazenamento de fotos inválida',
      );
    }
  }
}
