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

const falhasNome: Record<string, string> = {
  TITULO_AUSENTE: 'O leitor não reconheceu o título NOME na frente da CNH.',
  TITULO_DUPLICADO:
    'O leitor encontrou mais de um campo NOME e não conseguiu distinguir o titular.',
  ALTURA_INVALIDA: 'A posição do título NOME veio inválida na leitura.',
  PALAVRA_NA_BORDA:
    'A posição das palavras cruzou o limite identificado para o nome.',
  REGIAO_VAZIA:
    'O título NOME foi reconhecido, mas não foram encontradas palavras na região abaixo dele.',
  EXCESSO_DE_LINHAS:
    'A leitura misturou mais de duas linhas na região do nome.',
  NOME_DISTANTE: 'O texto do nome ficou separado demais do título na leitura.',
  OUTRO_CAMPO: 'A leitura misturou o nome com outro campo da CNH.',
  FORMATO_INVALIDO:
    'O texto reconhecido na região do nome contém caracteres incompatíveis com um nome completo.',
};
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
          : resultado.motivo === 'NOME_NAO_LIDO' && resultado.detalheLeitura
            ? (falhasNome[resultado.detalheLeitura] ??
              motivosCnh[resultado.motivo])
            : motivosCnh[resultado.motivo],
    };
  }
}
