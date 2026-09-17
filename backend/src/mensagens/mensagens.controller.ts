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
import { Conversa } from './conversa.entity';
import { Mensagem } from './mensagem.entity';
import { MensagensService } from './mensagens.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class MensagensController {
  constructor(private readonly mensagensService: MensagensService) {}

  @Post('solicitacoes/:idSolicitacao/conversa')
  async obterOuCriarConversa(
    @Param('idSolicitacao') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idSolicitacao = this.validarId(idRecebido, 'Solicitação inválida');
    const conversa = await this.mensagensService.obterOuCriarConversa(
      idSolicitacao,
      request.usuario.sub,
    );

    return { sucesso: true, dados: this.formatarConversa(conversa) };
  }

  @Get('conversas')
  async listarConversas(@Req() request: RequisicaoComUsuario) {
    const itens = await this.mensagensService.listarConversas(
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: itens.map(({ conversa, ultimaMensagem }) => ({
        ...this.formatarConversa(conversa),
        ultimaMensagem: ultimaMensagem
          ? this.formatarMensagem(ultimaMensagem)
          : null,
      })),
    };
  }

  @Get('conversas/:idConversa/mensagens')
  async listarMensagens(
    @Param('idConversa') idRecebido: string,
    @Query('antesDe') antesDeRecebido: string | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idConversa = this.validarId(idRecebido, 'Conversa inválida');
    const antesDe = antesDeRecebido
      ? this.validarId(antesDeRecebido, 'Mensagem inválida')
      : undefined;

    const mensagens = await this.mensagensService.listarMensagens(
      idConversa,
      request.usuario.sub,
      antesDe,
    );

    return {
      sucesso: true,
      dados: mensagens.map((mensagem) => this.formatarMensagem(mensagem)),
    };
  }

  @Post('conversas/:idConversa/mensagens')
  async enviarMensagem(
    @Param('idConversa') idRecebido: string,
    @Body() body: Record<string, unknown> | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idConversa = this.validarId(idRecebido, 'Conversa inválida');
    const conteudo = body?.conteudo?.toString() ?? '';
    const mensagem = await this.mensagensService.enviarMensagem(
      idConversa,
      request.usuario.sub,
      conteudo,
    );

    return {
      sucesso: true,
      mensagem: 'Mensagem enviada',
      dados: this.formatarMensagem(mensagem),
    };
  }

  private formatarConversa(conversa: Conversa) {
    const solicitacao = conversa.solicitacao;

    return {
      id: conversa.idConversa,
      status: solicitacao.status,
      solicitacao: {
        id: solicitacao.idSolicitacao,
        passageiro: {
          id: solicitacao.passageiro.idUsuario,
          nome: solicitacao.passageiro.nome,
        },
        motorista: {
          id: solicitacao.carona.usuario.idUsuario,
          nome: solicitacao.carona.usuario.nome,
        },
        carona: {
          id: solicitacao.carona.idCarona,
          destino: solicitacao.carona.destino,
          dataInicio: solicitacao.carona.dataInicio,
          horario: solicitacao.carona.horario,
        },
      },
      criadoEm: conversa.criadoEm,
    };
  }

  private formatarMensagem(mensagem: Mensagem) {
    return {
      id: mensagem.idMensagem,
      conteudo: mensagem.conteudo,
      criadoEm: mensagem.criadoEm,
      remetente: { id: mensagem.remetente.idUsuario },
    };
  }

  private validarId(valorRecebido: string, mensagem: string): number {
    const valor = Number(valorRecebido);

    if (!Number.isInteger(valor) || valor <= 0) {
      throw new BadRequestException(mensagem);
    }

    return valor;
  }
}
