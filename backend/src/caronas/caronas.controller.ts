import { Body, Controller, Get, Post } from '@nestjs/common'; // Importa os decorators usados pelo controller

import { CaronasService } from './caronas.service'; // Importa o service de caronas

@Controller('caronas') // Define que todas as rotas deste controller começam com /caronas
export class CaronasController {
  constructor(
    private readonly caronasService: CaronasService,
  ) {}

  @Post() // POST /caronas
  async criarCarona(@Body() body: any) {

    const carona = await this.caronasService.criarCarona(
      body.origem,
      body.destino,
      body.dataInicio,
      body.dataFim ?? null,
      body.horario,
      body.vagas,
      body.valor,
      body.recorrente ?? false,
      body.diasSemana,
      body.observacoes,
    );

    return {
      sucesso: true,
      mensagem: 'Carona criada com sucesso',
      dados: carona,
    };
  }

  @Get() // GET /caronas
  async listarCaronas() {

    const caronas = await this.caronasService.listarCaronas();

    return {
      sucesso: true,
      dados: caronas,
    };
  }
}