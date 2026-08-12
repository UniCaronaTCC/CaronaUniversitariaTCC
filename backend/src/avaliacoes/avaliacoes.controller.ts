import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { AvaliacoesService } from './avaliacoes.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AvaliacoesController {
  constructor(private readonly avaliacoesService: AvaliacoesService) {}

  @Post('avaliacoes')
  async criar(
    @Body() body: Record<string, unknown> | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idSolicitacao = Number(body?.idSolicitacao);
    const nota = Number(body?.nota);
    const comentario = body?.comentario?.toString().trim() || null;

    if (!Number.isInteger(idSolicitacao) || idSolicitacao <= 0) {
      throw new BadRequestException('Solicitação inválida');
    }

    if (!Number.isInteger(nota) || nota < 1 || nota > 5) {
      throw new BadRequestException('A nota deve ser de 1 a 5');
    }

    if (comentario != null && comentario.length > 500) {
      throw new BadRequestException('O comentário deve ter até 500 caracteres');
    }

    const avaliacao = await this.avaliacoesService.criar(
      request.usuario.sub,
      idSolicitacao,
      nota,
      comentario,
    );

    return {
      sucesso: true,
      mensagem: 'Avaliação enviada com sucesso',
      dados: { id: avaliacao.idAvaliacao },
    };
  }

  @Get('usuarios/:idUsuario/avaliacoes')
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
