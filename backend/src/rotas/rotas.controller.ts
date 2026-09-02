import { Body, Controller, Post } from '@nestjs/common';
import { RotasService } from './rotas.service';

@Controller('rotas')
export class RotasController {
  constructor(private readonly rotasService: RotasService) {}

  @Post('calcular')
  calcularRota(
    @Body() body: { coordenadas: number[][] },
  ) {
    return this.rotasService.calcularRota(body.coordenadas);
  }
}