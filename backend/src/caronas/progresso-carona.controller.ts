import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { ProgressoCaronaService } from './progresso-carona.service';

@Controller('caronas/:idCarona/progresso')
@UseGuards(JwtAuthGuard)
export class ProgressoCaronaController {
  constructor(private readonly service: ProgressoCaronaService) {}

  @Get()
  async consultar(
    @Param('idCarona', ParseIntPipe) id: number,
    @Req() req: RequisicaoComUsuario,
  ) {
    return {
      sucesso: true,
      dados: await this.service.consultar(id, req.usuario.sub),
    };
  }

  @Put(':idPonto')
  async marcar(
    @Param('idCarona', ParseIntPipe) id: number,
    @Param('idPonto', ParseIntPipe) ponto: number,
    @Req() req: RequisicaoComUsuario,
  ) {
    return {
      sucesso: true,
      dados: await this.service.marcar(id, ponto, req.usuario.sub),
    };
  }
}
