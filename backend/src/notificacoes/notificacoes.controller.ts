import {
  BadRequestException,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { NotificacoesService } from './notificacoes.service';

@UseGuards(JwtAuthGuard)
@Controller('notificacoes')
export class NotificacoesController {
  constructor(private readonly notificacoes: NotificacoesService) {}

  @Get('nao-lidas')
  async contar(@Req() request: RequisicaoComUsuario) {
    return {
      sucesso: true,
      dados: { total: await this.notificacoes.contar(request.usuario.sub) },
    };
  }

  @Get()
  async listar(
    @Req() request: RequisicaoComUsuario,
    @Query('antesDe') cursor?: string,
  ) {
    let antesDe: number | undefined;
    if (cursor !== undefined) {
      if (!/^[1-9]\d*$/.test(cursor) || Number(cursor) > 2147483647) {
        throw new BadRequestException('Notificacao invalida');
      }
      antesDe = Number(cursor);
    }
    return {
      sucesso: true,
      dados: await this.notificacoes.listar(request.usuario.sub, antesDe),
    };
  }

  @Post('abrir')
  async abrir(@Req() request: RequisicaoComUsuario) {
    return {
      sucesso: true,
      dados: await this.notificacoes.abrir(request.usuario.sub),
    };
  }
}
