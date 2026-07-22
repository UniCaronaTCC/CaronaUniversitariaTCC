import {
  BadRequestException,
  Body,
  Controller,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SolicitacoesService } from './solicitacoes.service';

interface RequisicaoComUsuario extends Request {
  usuario: {
    sub: number;
    email: string;
    nome: string;
  };
}

@Controller('caronas/:idCarona/solicitacoes')
export class SolicitacoesController {
  constructor(private readonly solicitacoesService: SolicitacoesService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async criarSolicitacao(
    @Param('idCarona') idCaronaRecebido: string,
    @Body() body: any,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idCarona = Number(idCaronaRecebido);
    const dados = body ?? {};
    const localEmbarque = dados.localEmbarque?.toString().trim() ?? '';

    if (!Number.isInteger(idCarona) || idCarona <= 0) {
      throw new BadRequestException('Carona inválida');
    }

    if (localEmbarque.isEmpty || localEmbarque.length > 255) {
      throw new BadRequestException('Local de embarque inválido');
    }

    const embarqueLatitude = this.validarCoordenada(
      dados.embarqueLatitude,
      -90,
      90,
      'Latitude do embarque',
    );
    const embarqueLongitude = this.validarCoordenada(
      dados.embarqueLongitude,
      -180,
      180,
      'Longitude do embarque',
    );

    const solicitacao = await this.solicitacoesService.criarSolicitacao({
      idCarona,
      idPassageiro: request.usuario.sub,
      localEmbarque,
      embarqueLatitude,
      embarqueLongitude,
    });

    return {
      sucesso: true,
      mensagem: 'Solicitação enviada ao motorista',
      dados: {
        id: solicitacao.idSolicitacao,
        status: solicitacao.status,
      },
    };
  }

  private validarCoordenada(
    valorRecebido: unknown,
    minimo: number,
    maximo: number,
    nome: string,
  ): number {
    const valor = Number(valorRecebido);

    if (!Number.isFinite(valor) || valor < minimo || valor > maximo) {
      throw new BadRequestException(`${nome} inválida`);
    }

    return valor;
  }
}
