import {
  BadRequestException,
  Body,
  Controller,
  Post,
  Req,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { VerificacaoCnhService } from './verificacao-cnh.service';

interface FotoCnh {
  buffer: Buffer;
}

interface FotosCnh {
  frente?: FotoCnh[];
  verso?: FotoCnh[];
}

@UseGuards(JwtAuthGuard)
@Controller('usuarios/cnh')
export class VerificacaoCnhController {
  constructor(private readonly verificacao: VerificacaoCnhService) {}

  @Post('verificar')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'frente', maxCount: 1 },
        { name: 'verso', maxCount: 1 },
      ],
      { limits: { files: 2, fileSize: 5 * 1024 * 1024, fields: 1 } },
    ),
  )
  async verificar(
    @UploadedFiles() arquivos: FotosCnh | undefined,
    @Body() body: Record<string, unknown> | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    const frente = arquivos?.frente?.[0]?.buffer;
    const verso = arquivos?.verso?.[0]?.buffer;

    try {
      if (body?.aceitePrivacidade !== 'true') {
        throw new BadRequestException('Aceite o aviso de privacidade');
      }
      if (!frente?.length || !verso?.length) {
        throw new BadRequestException(
          'Envie fotos da frente e do verso da CNH',
        );
      }
      if (!this.imagemPermitida(frente) || !this.imagemPermitida(verso)) {
        throw new BadRequestException('Envie fotos JPG, PNG ou WebP');
      }

      const resultado = await this.verificacao.verificar(
        request.usuario.sub,
        frente,
        verso,
      );
      return {
        sucesso: true,
        dados: resultado,
        mensagem:
          resultado.status === 'APROVADA'
            ? 'Dados da CNH conferidos para os testes'
            : 'Não foi possível conferir a CNH. Confira as fotos e tente novamente',
      };
    } finally {
      frente?.fill(0);
      verso?.fill(0);
    }
  }

  private imagemPermitida(arquivo: Buffer): boolean {
    return (
      (arquivo.length >= 3 &&
        arquivo[0] === 0xff &&
        arquivo[1] === 0xd8 &&
        arquivo[2] === 0xff) ||
      (arquivo.length >= 8 &&
        arquivo
          .subarray(0, 8)
          .equals(
            Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
          )) ||
      (arquivo.length >= 12 &&
        arquivo.subarray(0, 4).toString() === 'RIFF' &&
        arquivo.subarray(8, 12).toString() === 'WEBP')
    );
  }
}
