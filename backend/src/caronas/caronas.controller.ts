import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';

import { Carona } from './carona.entity';
import { CaronasService, DadosCriacaoCarona } from './caronas.service';

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
      this.validarDadosCarona(body, request.usuario.sub),
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
      this.validarDadosCarona(body, request.usuario.sub),
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

  @Get('minhas')
  async listarMinhasCaronas(@Req() request: RequisicaoComUsuario) {
    const caronas = await this.caronasService.listarMinhasCaronas(
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: caronas,
    };
  }

  @Get()
  async listarCaronas(@Req() request: RequisicaoComUsuario) {
    const caronas = await this.caronasService.listarCaronas(
      request.usuario.sub,
    );

    return {
      sucesso: true,
      dados: caronas,
    };
  }

  private validarDadosCarona(
    body: DadosCaronaRecebidos,
    idUsuario: number,
  ): DadosCriacaoCarona {
    const dados = body ?? {};

    const origem = dados.origem?.toString().trim() ?? '';
    const destino = dados.destino?.toString().trim() ?? '';
    const dataInicio = dados.dataInicio?.toString().trim() ?? '';
    const horario = dados.horario?.toString().trim() ?? '';

    if (!origem || !destino || !dataInicio || !horario) {
      throw new BadRequestException(
        'Origem, destino, data e horário são obrigatórios',
      );
    }

    if (origem.length > 255 || destino.length > 255) {
      throw new BadRequestException('Origem ou destino muito longo');
    }

    const vagas = Number(dados.vagas);
    const valor = Number(dados.valor);

    if (!Number.isInteger(vagas) || vagas <= 0 || vagas > 4) {
      throw new BadRequestException('Quantidade de vagas inválida');
    }

    if (!Number.isFinite(valor) || valor < 0) {
      throw new BadRequestException('Valor da carona inválido');
    }

    const recorrente = dados.recorrente === true;

    const diasSemana = Array.isArray(dados.diasSemana)
      ? dados.diasSemana.map((dia: unknown) => dia?.toString() ?? '')
      : null;

    if (
      recorrente &&
      (!Array.isArray(diasSemana) || diasSemana.length === 0)
    ) {
      throw new BadRequestException(
        'Selecione pelo menos um dia da semana',
      );
    }

    const pontosEmbarque = this.validarPontosEmbarque(
      dados.pontosEmbarque,
    );

    return {
      idUsuario,

      origem,

      origemCidade: this.textoOpcional(
        dados.origemCidade,
        100,
      ),

      origemLatitude: this.validarCoordenada(
        dados.origemLatitude,
        -90,
        90,
        'Latitude da origem',
      ),

      origemLongitude: this.validarCoordenada(
        dados.origemLongitude,
        -180,
        180,
        'Longitude da origem',
      ),

      destino,

      destinoCidade: this.textoOpcional(
        dados.destinoCidade,
        100,
      ),

      destinoLatitude: this.validarCoordenada(
        dados.destinoLatitude,
        -90,
        90,
        'Latitude do destino',
      ),

      destinoLongitude: this.validarCoordenada(
        dados.destinoLongitude,
        -180,
        180,
        'Longitude do destino',
      ),

      dataInicio,

      dataFim: this.textoOpcional(
        dados.dataFim,
      ),

      horario,
      vagas,
      valor,
      recorrente,
      diasSemana,

      observacoes:
          this.textoOpcional(dados.observacoes) ?? undefined,

      pontosEmbarque,
    };
  }

  private validarPontosEmbarque(valor: unknown) {
    if (valor == null) {
      return [];
    }

    if (!Array.isArray(valor)) {
      throw new BadRequestException(
        'Pontos de embarque inválidos',
      );
    }

    return valor.map((item, indice) => {
      if (typeof item !== 'object' || item === null) {
        throw new BadRequestException(
          `Ponto de embarque ${indice + 1} inválido`,
        );
      }

      const ponto = item as Record<string, unknown>;

      const endereco =
          ponto.endereco?.toString().trim() ?? '';

      if (!endereco) {
        throw new BadRequestException(
          `Endereço do ponto de embarque ${indice + 1} é obrigatório`,
        );
      }

      if (endereco.length > 255) {
        throw new BadRequestException(
          `Endereço do ponto de embarque ${indice + 1} muito longo`,
        );
      }

      return {
        nome: this.textoOpcional(
          ponto.nome,
          100,
        ),

        endereco,

        latitude: this.validarCoordenada(
          ponto.latitude,
          -90,
          90,
          `Latitude do ponto de embarque ${indice + 1}`,
        ),

        longitude: this.validarCoordenada(
          ponto.longitude,
          -180,
          180,
          `Longitude do ponto de embarque ${indice + 1}`,
        ),

        ordem: indice + 1,
      };
    });
  }

  private validarIdCarona(idRecebido: string): number {
    const idCarona = Number(idRecebido);

    if (!Number.isInteger(idCarona) || idCarona <= 0) {
      throw new BadRequestException('Carona inválida');
    }

    return idCarona;
  }

  private textoOpcional(
    valor: unknown,
    limite?: number,
  ): string | null {
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

    if (
      !Number.isFinite(valor) ||
      valor < minimo ||
      valor > maximo
    ) {
      throw new BadRequestException(`${nome} inválida`);
    }

    return valor;
  }

  private formatarCarona(carona: Carona) {
    return {
      idCarona: carona.idCarona,

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
      },
    };
  }
}
