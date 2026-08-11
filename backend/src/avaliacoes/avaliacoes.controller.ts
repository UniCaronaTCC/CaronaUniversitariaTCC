import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AvaliacoesService } from './avaliacoes.service';

@UseGuards(JwtAuthGuard)
@Controller('usuarios')
export class AvaliacoesController {
  constructor(private readonly avaliacoesService: AvaliacoesService) {}

  @Get(':idUsuario/avaliacoes')
  async listarRecebidas(
    @Param('idUsuario') idRecebido: string,
    @Query('pagina') paginaRecebida?: string,
  ) {
    const idUsuario = Number(idRecebido);
    const pagina = paginaRecebida == null ? 1 : Number(paginaRecebida);

    if (!Number.isInteger(idUsuario) || idUsuario <= 0) {
      throw new BadRequestException('Usuário inválido');
    }

    if (!Number.isInteger(pagina) || pagina <= 0) {
      throw new BadRequestException('Página inválida');
    }

    const resultado = await this.avaliacoesService.listarRecebidas(
      idUsuario,
      pagina,
    );

    return {
      sucesso: true,
      dados: {
        media: resultado.media,
        total: resultado.total,
        pagina: resultado.pagina,
        totalPaginas: resultado.totalPaginas,
        avaliacoes: resultado.avaliacoes.map((avaliacao) => ({
          id: avaliacao.idAvaliacao,
          nota: avaliacao.nota,
          comentario: avaliacao.comentario,
          criadoEm: avaliacao.criadoEm,
          avaliador: {
            id: avaliacao.avaliador.idUsuario,
            nome: avaliacao.avaliador.nome,
          },
        })),
      },
    };
  }
}
