import { BadRequestException, Controller, Get, Query } from '@nestjs/common';

import { InstituicoesService } from './instituicoes.service';

@Controller('instituicoes')
export class InstituicoesController {
  constructor(private readonly instituicoesService: InstituicoesService) {}

  @Get()
  async buscar(@Query('busca') buscaRecebida?: string) {
    const busca = buscaRecebida?.trim() ?? '';

    if (busca.length < 2 || busca.length > 100) {
      throw new BadRequestException('Digite entre 2 e 100 caracteres');
    }

    const instituicoes = await this.instituicoesService.buscar(busca);

    return {
      sucesso: true,
      dados: instituicoes.map((instituicao) => ({
        id: instituicao.idInstituicao,
        codigoEmec: instituicao.codigoEmec,
        nome: instituicao.nome,
        sigla: instituicao.sigla,
        municipio: instituicao.municipio,
        uf: instituicao.uf,
      })),
    };
  }
}
