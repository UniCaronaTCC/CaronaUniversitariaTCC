import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';

import { Solicitacao } from './solicitacao.entity';
import { SolicitacoesService } from './solicitacoes.service';

type DadosSolicitacaoRecebidos = Record<string, unknown> | undefined;

@UseGuards(JwtAuthGuard)
@Controller()
export class SolicitacoesController {
  constructor(
    private readonly solicitacoesService: SolicitacoesService,
  ) {}

  @Post('caronas/:idCarona/solicitacoes')
  async criarSolicitacao(
    @Param('idCarona') idCaronaRecebido: string,
    @Body() body: DadosSolicitacaoRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idCarona = this.validarId(idCaronaRecebido, 'Carona inválida');
    const dados = body ?? {};

    const tipoPontoEmbarque = dados.tipoPontoEmbarque
      ?.toString()
      .trim()
      .toUpperCase();

    if (
      tipoPontoEmbarque !== 'EXISTENTE' &&
      tipoPontoEmbarque !== 'NOVO_SOLICITADO'
    ) {
      throw new BadRequestException(
        'Tipo de ponto de embarque inválido',
      );
    }

    if (tipoPontoEmbarque === 'EXISTENTE') {
      const idPontoEmbarque = Number(dados.idPontoEmbarque);

      if (!Number.isInteger(idPontoEmbarque) || idPontoEmbarque <= 0) {
        throw new BadRequestException(
          'Selecione um ponto de embarque válido',
        );
      }

      const solicitacao =
        await this.solicitacoesService.criarSolicitacao({
          idCarona,
          idPassageiro: request.usuario.sub,
          tipoPontoEmbarque: 'EXISTENTE',
          idPontoEmbarque,
        });

      return this.respostaCriacao(solicitacao);
    }

    const localEmbarque =
      dados.localEmbarque?.toString().trim() ?? '';

    if (!localEmbarque || localEmbarque.length > 255) {
      throw new BadRequestException(
        'Local de embarque inválido',
      );
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

    const solicitacao =
      await this.solicitacoesService.criarSolicitacao({
        idCarona,
        idPassageiro: request.usuario.sub,
        tipoPontoEmbarque: 'NOVO_SOLICITADO',
        localEmbarque,
        embarqueLatitude,
        embarqueLongitude,
      });

    return this.respostaCriacao(solicitacao);
  }

  @Get('solicitacoes/recebidas')
  async listarRecebidas(
    @Req() request: RequisicaoComUsuario,
  ) {
    const solicitacoes =
      await this.solicitacoesService.listarRecebidas(
        request.usuario.sub,
      );

    return {
      sucesso: true,
      dados: solicitacoes.map((solicitacao) =>
        this.formatarSolicitacaoRecebida(solicitacao),
      ),
    };
  }

  @Get('caronas/:idCarona/solicitacoes')
  async listarRecebidasDaCarona(
    @Param('idCarona') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idCarona = this.validarId(
      idRecebido,
      'Carona inválida',
    );

    const solicitacoes =
      await this.solicitacoesService.listarRecebidasDaCarona(
        request.usuario.sub,
        idCarona,
      );

    return {
      sucesso: true,
      dados: solicitacoes.map((solicitacao) =>
        this.formatarSolicitacaoRecebida(solicitacao),
      ),
    };
  }

  @Get('solicitacoes/enviadas')
  async listarEnviadas(
    @Req() request: RequisicaoComUsuario,
  ) {
    const solicitacoes =
      await this.solicitacoesService.listarEnviadas(
        request.usuario.sub,
      );

    return {
      sucesso: true,
      dados: solicitacoes.map((solicitacao) => ({
        id: solicitacao.idSolicitacao,
        status: solicitacao.status,
        avaliada: solicitacao.avaliada,
        podeAvaliar: solicitacao.podeAvaliar,

        tipoPontoEmbarque: solicitacao.tipoPontoEmbarque,
        idPontoEmbarque:
          solicitacao.pontoEmbarque?.idPontoEmbarque ?? null,

        localEmbarque: solicitacao.localEmbarque,
        embarqueLatitude: solicitacao.embarqueLatitude,
        embarqueLongitude: solicitacao.embarqueLongitude,

        criadoEm: solicitacao.criadoEm,

        motorista: {
          id: solicitacao.carona.usuario.idUsuario,
          nome: solicitacao.carona.usuario.nome,
        },

        carona: {
          id: solicitacao.carona.idCarona,
          destino: solicitacao.carona.destino,
          dataInicio: solicitacao.carona.dataInicio,
          horario: solicitacao.carona.horario,
          valor: solicitacao.carona.valor,
          status: solicitacao.carona.status,
        },
      })),
    };
  }

  @Patch('solicitacoes/:idSolicitacao/status')
  async responderSolicitacao(
    @Param('idSolicitacao') idRecebido: string,
    @Body() body: DadosSolicitacaoRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idSolicitacao = this.validarId(
      idRecebido,
      'Solicitação inválida',
    );

    const status = body?.status
      ?.toString()
      .trim()
      .toUpperCase();

    if (status !== 'ACEITA' && status !== 'RECUSADA') {
      throw new BadRequestException('Resposta inválida');
    }

    const solicitacao =
      await this.solicitacoesService.responderSolicitacao(
        idSolicitacao,
        request.usuario.sub,
        status,
      );

    return {
      sucesso: true,
      mensagem:
        status === 'ACEITA'
          ? 'Solicitação aceita com sucesso'
          : 'Solicitação recusada',
      dados: {
        id: solicitacao.idSolicitacao,
        status: solicitacao.status,
      },
    };
  }

  @Patch('solicitacoes/:idSolicitacao/cancelar')
  async cancelarSolicitacao(
    @Param('idSolicitacao') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const idSolicitacao = this.validarId(
      idRecebido,
      'Solicitação inválida',
    );

    const solicitacao =
      await this.solicitacoesService.cancelarSolicitacao(
        idSolicitacao,
        request.usuario.sub,
      );

    return {
      sucesso: true,
      mensagem: 'Cancelamento realizado com sucesso',
      dados: {
        id: solicitacao.idSolicitacao,
        status: solicitacao.status,
      },
    };
  }

  private respostaCriacao(solicitacao: Solicitacao) {
    return {
      sucesso: true,
      mensagem: 'Solicitação enviada ao motorista',
      dados: {
        id: solicitacao.idSolicitacao,
        status: solicitacao.status,
        tipoPontoEmbarque: solicitacao.tipoPontoEmbarque,
        idPontoEmbarque:
          solicitacao.pontoEmbarque?.idPontoEmbarque ?? null,
      },
    };
  }

  private formatarSolicitacaoRecebida(
    solicitacao: Solicitacao,
  ) {
    return {
      id: solicitacao.idSolicitacao,
      status: solicitacao.status,
      avaliada: solicitacao.avaliada,
      podeAvaliar: solicitacao.podeAvaliar,

      tipoPontoEmbarque: solicitacao.tipoPontoEmbarque,
      idPontoEmbarque:
        solicitacao.pontoEmbarque?.idPontoEmbarque ?? null,

      localEmbarque: solicitacao.localEmbarque,
      embarqueLatitude: solicitacao.embarqueLatitude,
      embarqueLongitude: solicitacao.embarqueLongitude,

      criadoEm: solicitacao.criadoEm,

      passageiro: {
        id: solicitacao.passageiro.idUsuario,
        nome: solicitacao.passageiro.nome,
      },

      carona: {
        id: solicitacao.carona.idCarona,
        destino: solicitacao.carona.destino,
        dataInicio: solicitacao.carona.dataInicio,
        horario: solicitacao.carona.horario,
        status: solicitacao.carona.status,
      },
    };
  }

  private validarId(
    valorRecebido: string,
    mensagem: string,
  ): number {
    const valor = Number(valorRecebido);

    if (!Number.isInteger(valor) || valor <= 0) {
      throw new BadRequestException(mensagem);
    }

    return valor;
  }

  private validarCoordenada(
    valorRecebido: unknown,
    minimo: number,
    maximo: number,
    nome: string,
  ): number {
    const valor = Number(valorRecebido);

    if (
      !Number.isFinite(valor) ||
      valor < minimo ||
      valor > maximo
    ) {
      throw new BadRequestException(`${nome} inválida`);
    }

    return valor;
  }
}