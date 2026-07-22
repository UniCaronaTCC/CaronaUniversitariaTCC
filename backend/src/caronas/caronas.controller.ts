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
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Carona } from './carona.entity';
import { CaronasService, DadosCriacaoCarona } from './caronas.service';

interface RequisicaoComUsuario extends Request {
  usuario: {
    sub: number;
    email: string;
    nome: string;
  };
}

@UseGuards(JwtAuthGuard)
@Controller('caronas')
export class CaronasController {
  constructor(private readonly caronasService: CaronasService) {}

  @Post()
  async criarCarona(@Body() body: any, @Req() request: RequisicaoComUsuario) {
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
    @Body() body: any,
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

  private validarDadosCarona(body: any, idUsuario: number): DadosCriacaoCarona {
    const dados = body ?? {};

    if (
      !dados.origem ||
      !dados.destino ||
      !dados.dataInicio ||
      !dados.horario
    ) {
      throw new BadRequestException(
        'Origem, destino, data e horário são obrigatórios',
      );
    }

    const vagas = Number(dados.vagas);
    const valor = Number(dados.valor);

    if (!Number.isInteger(vagas) || vagas <= 0) {
      throw new BadRequestException('Quantidade de vagas inválida');
    }

    if (!Number.isFinite(valor) || valor < 0) {
      throw new BadRequestException('Valor da carona inválido');
    }

    const recorrente = dados.recorrente === true;
    const diasSemana = dados.diasSemana ?? null;

    if (recorrente && (!Array.isArray(diasSemana) || diasSemana.length === 0)) {
      throw new BadRequestException('Selecione pelo menos um dia da semana');
    }

    return {
      idUsuario,
      origem: dados.origem,
      origemCidade: dados.origemCidade ?? null,
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
      destino: dados.destino,
      destinoCidade: dados.destinoCidade ?? null,
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
      dataInicio: dados.dataInicio,
      dataFim: dados.dataFim ?? null,
      horario: dados.horario,
      vagas,
      valor,
      recorrente,
      diasSemana,
      observacoes: dados.observacoes,
    };
  }

  private validarIdCarona(idRecebido: string): number {
    const idCarona = Number(idRecebido);

    if (!Number.isInteger(idCarona) || idCarona <= 0) {
      throw new BadRequestException('Carona inválida');
    }

    return idCarona;
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
      usuario: {
        idUsuario: carona.usuario.idUsuario,
        nome: carona.usuario.nome,
      },
    };
  }
}
