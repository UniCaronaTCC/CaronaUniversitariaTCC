import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { Pagamento } from './pagamento.entity';
import { PagamentosService } from './pagamentos.service';

@UseGuards(JwtAuthGuard)
@Controller('pagamentos')
export class PagamentosController {
  constructor(private readonly pagamentosService: PagamentosService) {}

  @Get(':idPagamento')
  async obterPagamento(
    @Param('idPagamento') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idPagamento = this.validarId(idRecebido, 'Pagamento invalido');
    const pagamento = await this.pagamentosService.obterPagamento(
      idPagamento,
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: this.formatarPagamento(pagamento),
    };
  }

  @Post('solicitacoes/:idSolicitacao/pix')
  async criarOuObterPix(
    @Param('idSolicitacao') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idSolicitacao = this.validarId(idRecebido, 'Solicitacao invalida');
    const pagamento = await this.pagamentosService.criarOuObterPix(
      idSolicitacao,
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: this.formatarPagamento(pagamento),
    };
  }

  private formatarPagamento(pagamento: Pagamento) {
    return {
      id: pagamento.idPagamento,
      idSolicitacao: pagamento.solicitacao.idSolicitacao,
      metodo: pagamento.metodo,
      valorCentavos: pagamento.valorCentavos,
      statusCriacao: pagamento.statusCriacao,
      status: pagamento.statusProvedor,
      pixCopiaECola: pagamento.pixCopiaECola,
      qrCodeBase64: pagamento.qrCodeBase64,
      expiraEm: pagamento.expiraEm,
      modoTeste: pagamento.modoTeste,
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
