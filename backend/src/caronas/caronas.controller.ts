import { DIAS_SEMANA } from './datas-recorrencia';
import { ValidacaoCarona } from './validacao-carona';
import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';

import { Carona } from './carona.entity';
import { CaronasService, DadosPosicaoAtualCarona } from './caronas.service';

type DadosCaronaRecebidos = Record<string, unknown> | undefined;

@UseGuards(JwtAuthGuard)
@Controller('caronas')
export class CaronasController {
  constructor(private readonly caronasService: CaronasService) {}

  @Post()
  async criarCarona(
    @Body() body: DadosCaronaRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const carona = await this.caronasService.criarCarona(
      new ValidacaoCarona().validarDadosCarona(body, request.usuario.sub),
    );

    return {
      sucesso: true,
      mensagem: 'Carona criada com sucesso',
      dados: this.formatarCarona(carona),
    };
  }

  @Patch(':idCarona')
  async atualizarCarona(
    @Param('idCarona') idRecebido: string,
    @Body() body: DadosCaronaRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const carona = await this.caronasService.atualizarCarona(
      this.validarIdCarona(idRecebido),
      new ValidacaoCarona().validarDadosCarona(body, request.usuario.sub),
    );

    return {
      sucesso: true,
      mensagem: 'Carona atualizada com sucesso',
      dados: this.formatarCarona(carona),
    };
  }

  @Delete(':idCarona')
  async excluirCarona(
    @Param('idCarona') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    await this.caronasService.excluirCarona(
      this.validarIdCarona(idRecebido),
      request.usuario.sub,
    );

    return {
      sucesso: true,
      mensagem: 'Carona excluída com sucesso',
    };
  }

  @Patch(':idCarona/iniciar')
  async iniciarCarona(
    @Param('idCarona') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const carona = await this.caronasService.iniciarCarona(
      this.validarIdCarona(idRecebido),
      request.usuario.sub,
    );
    return {
      sucesso: true,
      mensagem: 'Corrida iniciada com sucesso',
      dados: this.formatarCarona(carona),
    };
  }

  @Patch(':idCarona/finalizar')
  async finalizarCarona(
    @Param('idCarona') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const carona = await this.caronasService.finalizarCarona(
      this.validarIdCarona(idRecebido),
      request.usuario.sub,
    );
    return {
      sucesso: true,
      mensagem: 'Corrida finalizada com sucesso',
      dados: this.formatarCarona(carona),
    };
  }

  @Put(':idCarona/posicao')
  async atualizarPosicaoAtual(
    @Param('idCarona') idRecebido: string,
    @Body() body: DadosCaronaRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const posicao = await this.caronasService.atualizarPosicaoAtual(
      this.validarIdCarona(idRecebido),
      request.usuario.sub,
      this.validarPosicaoAtual(body),
    );

    return {
      sucesso: true,
      dados: this.formatarPosicaoAtual(posicao),
    };
  }

  @Get(':idCarona/posicao')
  async buscarPosicaoAtual(
    @Param('idCarona') idRecebido: string,
    @Req() request: RequisicaoComUsuario,
  ) {
    const posicao = await this.caronasService.buscarPosicaoAtual(
      this.validarIdCarona(idRecebido),
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: posicao == null ? null : this.formatarPosicaoAtual(posicao),
    };
  }

  @Get('minhas')
  async listarMinhasCaronas(@Req() request: RequisicaoComUsuario) {
    const caronas = await this.caronasService.listarMinhasCaronas(
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: caronas.map((carona) => ({
        ...this.formatarCarona(carona),
        diasRecorrencia:
          carona.programacao?.diasSemana.map((dia) => DIAS_SEMANA[dia % 7]) ??
          [],
      })),
    };
  }

  @Get()
  async listarCaronas(@Req() request: RequisicaoComUsuario) {
    const caronas = await this.caronasService.listarCaronas(
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: caronas.map((carona) => this.formatarCarona(carona)),
    };
  }

  private validarPosicaoAtual(
    body: DadosCaronaRecebidos,
  ): DadosPosicaoAtualCarona {
    const dados = body ?? {};
    const direcaoRecebida = dados.direcao;

    return {
      latitude: this.validarCoordenada(dados.latitude, -90, 90, 'Latitude'),
      longitude: this.validarCoordenada(
        dados.longitude,
        -180,
        180,
        'Longitude',
      ),
      direcao:
        direcaoRecebida == null
          ? null
          : this.validarCoordenada(direcaoRecebida, 0, 360, 'Direção'),
      precisao: this.validarCoordenada(dados.precisao, 0, 10000, 'Precisão'),
    };
  }

  private validarIdCarona(idRecebido: string): number {
    const idCarona = Number(idRecebido);

    if (!Number.isInteger(idCarona) || idCarona <= 0) {
      throw new BadRequestException('Carona inválida');
    }

    return idCarona;
  }

  private textoOpcional(valor: unknown, limite?: number): string | null {
    const texto = valor?.toString().trim() ?? '';

    if (limite != null && texto.length > limite) {
      throw new BadRequestException('Texto muito longo');
    }

    return texto || null;
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

  private formatarCarona(carona: Carona) {
    return {
      idCarona: carona.idCarona,
      idRecorrencia: carona.idRecorrencia,

      origem: carona.origem,
      origemCidade: carona.origemCidade,
      origemLatitude: carona.origemLatitude,
      origemLongitude: carona.origemLongitude,

      destino: carona.destino,
      destinoCidade: carona.destinoCidade,
      destinoLatitude: carona.destinoLatitude,
      destinoLongitude: carona.destinoLongitude,

      dataInicio: carona.dataInicio,
      dataFim: carona.dataFim,
      horario: carona.horario,
      vagas: carona.vagas,
      valor: carona.valor,
      recorrente: carona.recorrente,
      diasSemana: carona.diasSemana,
      observacoes: carona.observacoes,
      status: carona.status,

      pontosEmbarque:
        carona.pontosEmbarque?.map((ponto) => ({
          idPontoEmbarque: ponto.idPontoEmbarque,
          nome: ponto.nome,
          endereco: ponto.endereco,
          latitude: ponto.latitude,
          longitude: ponto.longitude,
          ordem: ponto.ordem,
        })) ?? [],

      usuario: {
        idUsuario: carona.usuario.idUsuario,
        nome: carona.usuario.nome,
        veiculo: carona.usuario.veiculo
          ? {
              modelo: carona.usuario.veiculo.modelo,
              cor: carona.usuario.veiculo.cor,
              placa: this.mascararPlaca(carona.usuario.veiculo.placa),
            }
          : null,
      },
    };
  }

  private formatarPosicaoAtual(posicao: {
    latitude: number;
    longitude: number;
    direcao: number | null;
    precisao: number;
    atualizadoEm: Date;
  }) {
    return {
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      direcao: posicao.direcao,
      precisao: posicao.precisao,
      atualizadoEm: posicao.atualizadoEm,
    };
  }

  private mascararPlaca(placa: string): string {
    const placaNormalizada = placa.toUpperCase().replace(/[^A-Z0-9]/g, '');
    return `***${placaNormalizada.slice(-4)}`;
  }
}
