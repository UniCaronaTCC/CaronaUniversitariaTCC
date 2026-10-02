import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { RecorrenciasService } from './recorrencias.service';
import { ValidacaoCarona } from './validacao-carona';
import { RecorrenciaCarona } from './recorrencia.entity';

@Controller('recorrencias')
@UseGuards(JwtAuthGuard)
export class RecorrenciasController {
  constructor(private readonly service: RecorrenciasService) {}

  @Get()
  async listar(@Req() req: RequisicaoComUsuario) {
    return {
      sucesso: true,
      dados: (await this.service.listar(req.usuario.sub)).map((modelo) =>
        this.formatar(modelo),
      ),
    };
  }

  @Patch(':id')
  async editar(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Record<string, unknown>,
    @Req() req: RequisicaoComUsuario,
  ) {
    const dados = new ValidacaoCarona().validarDadosCarona(
      body,
      req.usuario.sub,
    );
    if (!dados.recorrente)
      throw new BadRequestException('Selecione os dias da programação');
    const modelo = await this.service.atualizar(id, req.usuario.sub, dados);
    return {
      sucesso: true,
      dados: this.formatar(modelo),
      mensagem: 'Programação atualizada. Caronas já publicadas foram mantidas.',
    };
  }

  @Patch(':id/estado')
  async alterarEstado(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: { ativa?: unknown },
    @Req() req: RequisicaoComUsuario,
  ) {
    if (typeof body?.ativa !== 'boolean')
      throw new BadRequestException('Estado inválido');
    return {
      sucesso: true,
      dados: this.formatar(
        await this.service.atualizar(
          id,
          req.usuario.sub,
          undefined,
          body.ativa,
        ),
      ),
    };
  }

  private formatar(modelo: RecorrenciaCarona) {
    return {
      idRecorrencia: modelo.idRecorrencia,
      ativa: modelo.ativa,
      dados: modelo.dados,
    };
  }
}
