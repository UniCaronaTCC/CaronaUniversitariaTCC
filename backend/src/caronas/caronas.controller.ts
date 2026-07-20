import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CaronasService } from './caronas.service';

interface RequisicaoComUsuario extends Request {
  usuario: {
    sub: number;
    email: string;
    nome: string;
  };
}

@Controller('caronas')
export class CaronasController {
  constructor(
    private readonly caronasService: CaronasService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  async criarCarona(
    @Body() body: any,
    @Req() request: RequisicaoComUsuario,
  ) {
    const dados = body ?? {};

    // Valida os textos obrigatorios.
    if (
      !dados.origem ||
      !dados.destino ||
      !dados.dataInicio ||
      !dados.horario
    ) {
      throw new BadRequestException(
        'Origem, destino, data e horario sao obrigatorios',
      );
    }

    const vagas = Number(dados.vagas);
    const valor = Number(dados.valor);

    if (!Number.isInteger(vagas) || vagas <= 0) {
      throw new BadRequestException(
        'Quantidade de vagas invalida',
      );
    }

    if (!Number.isFinite(valor) || valor < 0) {
      throw new BadRequestException(
        'Valor da carona invalido',
      );
    }

    // Valida as coordenadas recebidas do mapa e da busca.
    const origemLatitude = this.validarCoordenada(
      dados.origemLatitude,
      -90,
      90,
      'Latitude da origem',
    );

    const origemLongitude = this.validarCoordenada(
      dados.origemLongitude,
      -180,
      180,
      'Longitude da origem',
    );

    const destinoLatitude = this.validarCoordenada(
      dados.destinoLatitude,
      -90,
      90,
      'Latitude do destino',
    );

    const destinoLongitude = this.validarCoordenada(
      dados.destinoLongitude,
      -180,
      180,
      'Longitude do destino',
    );

    const recorrente = dados.recorrente === true;
    const diasSemana = dados.diasSemana ?? null;

    if (
      recorrente &&
      (!Array.isArray(diasSemana) || diasSemana.length === 0)
    ) {
      throw new BadRequestException(
        'Selecione pelo menos um dia da semana',
      );
    }

    const carona = await this.caronasService.criarCarona({
      idUsuario: request.usuario.sub,

      origem: dados.origem,
      origemCidade: dados.origemCidade ?? null,
      origemLatitude,
      origemLongitude,

      destino: dados.destino,
      destinoCidade: dados.destinoCidade ?? null,
      destinoLatitude,
      destinoLongitude,

      dataInicio: dados.dataInicio,
      dataFim: dados.dataFim ?? null,
      horario: dados.horario,
      vagas,
      valor,
      recorrente,
      diasSemana,
      observacoes: dados.observacoes,
    });

    return {
      sucesso: true,
      mensagem: 'Carona criada com sucesso',
      dados: carona,
    };
  }

  @Get()
  async listarCaronas() {
    const caronas =
        await this.caronasService.listarCaronas();

    return {
      sucesso: true,
      dados: caronas,
    };
  }

  // Converte e valida latitude ou longitude.
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
      throw new BadRequestException(
        `${nome} invalida`,
      );
    }

    return valor;
  }
}