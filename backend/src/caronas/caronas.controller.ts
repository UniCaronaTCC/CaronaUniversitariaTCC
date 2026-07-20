import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
// Importa os decorators usados pelo controller

import { Request } from 'express';
// Importa o tipo Request para acessar a requisição HTTP

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
// Importa o guard que valida o token JWT

import { CaronasService } from './caronas.service';
// Importa o service responsável pelas regras das caronas

interface RequisicaoComUsuario extends Request {
  usuario: {
    sub: number;
    email: string;
    nome: string;
  };
}
// Define o formato da requisição depois que o JwtAuthGuard adiciona o usuário

@Controller('caronas')
// Define que todas as rotas começam com /caronas
export class CaronasController {
  constructor(
    private readonly caronasService: CaronasService,
  ) {}

  @UseGuards(JwtAuthGuard)
  // Protege esta rota: só cria carona se o usuário estiver logado

  @Post()
  // Cria uma nova oferta usando POST /caronas
  async criarCarona(
    @Body() body: any,
    @Req() request: RequisicaoComUsuario,
  ) {

    // Garante que, se o body vier vazio, ele vire um objeto vazio
    const dados = body ?? {};

    // Valida campos de texto obrigatórios
    if (!dados.origem || !dados.destino || !dados.dataInicio || !dados.horario) {
      throw new BadRequestException(
        'Origem, destino, data e horário são obrigatórios',
      );
    }

    // Converte vagas e valor para número
    const vagas = Number(dados.vagas);
    const valor = Number(dados.valor);

    // Valida se vagas é um número válido e maior que zero
    if (!Number.isFinite(vagas) || vagas <= 0) {
      throw new BadRequestException(
        'Quantidade de vagas inválida',
      );
    }

    // Valida se valor é um número válido e não negativo
    if (!Number.isFinite(valor) || valor < 0) {
      throw new BadRequestException(
        'Valor da carona inválido',
      );
    }

    // Garante que recorrente seja booleano
    const recorrente = dados.recorrente === true;

    // Define os dias da semana, quando existirem
    const diasSemana = dados.diasSemana ?? null;

    // Se a carona for recorrente, precisa ter pelo menos um dia selecionado
    if (
      recorrente &&
      (!Array.isArray(diasSemana) || diasSemana.length === 0)
    ) {
      throw new BadRequestException(
        'Selecione pelo menos um dia da semana para a carona recorrente',
      );
    }

    // Pega o id do usuário logado a partir do token JWT
    const idUsuario = request.usuario.sub;

    const carona = await this.caronasService.criarCarona(
      idUsuario,
      dados.origem,
      dados.destino,
      dados.dataInicio,
      dados.dataFim ?? null,
      dados.horario,
      vagas,
      valor,
      recorrente,
      diasSemana,
      dados.observacoes,
    );

    return {
      sucesso: true,
      mensagem: 'Carona criada com sucesso',
      dados: carona,
    };
  }

  @Get()
  // Lista as ofertas existentes usando GET /caronas
  // Esta rota continua pública, porque qualquer usuário pode ver caronas disponíveis
  async listarCaronas() {

    const caronas = await this.caronasService.listarCaronas();

    return {
      sucesso: true,
      dados: caronas,
    };
  }
} 