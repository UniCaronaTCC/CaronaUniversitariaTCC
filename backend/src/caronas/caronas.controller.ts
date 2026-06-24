import {
  Body,
  Controller,
  Get,
  Post,
} from '@nestjs/common';
// Importa os decorators usados pelo controller

import { CaronasService } from './caronas.service';
// Importa o service responsável pelas regras das caronas

@Controller('caronas')
// Define que todas as rotas começam com /caronas
export class CaronasController {
  constructor(
    private readonly caronasService: CaronasService,
  ) {}

  @Post()
  // Cria uma nova oferta usando POST /caronas
  async criarCarona(@Body() body: any) {
    const carona = await this.caronasService.criarCarona(
      body.origem,
      body.destino,
      body.dataInicio,
      body.dataFim ?? null,
      body.horario,

      // Garante que vagas seja tratado como número inteiro
      Number(body.vagas),

      // Garante que valor seja tratado como número decimal
      Number(body.valor),

      // Garante que recorrente seja um valor booleano
      body.recorrente === true,

      // Quando não houver recorrência, os dias ficam nulos
      body.diasSemana ?? null,

      body.observacoes,
    );

    return {
      sucesso: true,
      mensagem: 'Carona criada com sucesso',
      dados: carona,
    };
  }

  @Get()
  // Lista as ofertas existentes usando GET /caronas
  async listarCaronas() {
    const caronas = await this.caronasService.listarCaronas();

    return {
      sucesso: true,
      dados: caronas,
    };
  }
}