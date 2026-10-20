import {
  BadRequestException,
  Body,
  Controller,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { VerificacaoCnhService } from './verificacao-cnh.service';
import { motivosCnh } from './dados-cnh';
@UseGuards(JwtAuthGuard)
@Controller('usuarios/cnh')
export class VerificacaoCnhController {
  constructor(private readonly verificacao: VerificacaoCnhService) {}
  @Post('reiniciar-teste')
  async reiniciarTeste(@Req() request: RequisicaoComUsuario) {
    return {
      sucesso: true,
      dados: await this.verificacao.reiniciarParaTeste(request.usuario.sub),
      mensagem: 'Verificação reiniciada para testes',
    };
  }
  @Post(['verificar', 'verificar-mlkit'])
  async verificar(
    @Body() body: Record<string, unknown> | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    if (body?.versaoLeitura !== 'mlkit-v1')
      throw new BadRequestException(
        'Atualize o app para verificar a CNH com o novo leitor.',
      );
    if (body.aceitePrivacidade !== true)
      throw new BadRequestException('Aceite o aviso de privacidade');
    const resultado = await this.verificacao.verificar(
      request.usuario.sub,
      body.leitura,
      typeof body.nomeCompleto === 'string' ? body.nomeCompleto : '',
    );
    return {
      sucesso: true,
      dados: resultado,
      mensagem:
        resultado.status === 'APROVADA'
          ? 'Dados da CNH conferidos para os testes'
          : motivosCnh[resultado.motivo],
    };
  }
}
