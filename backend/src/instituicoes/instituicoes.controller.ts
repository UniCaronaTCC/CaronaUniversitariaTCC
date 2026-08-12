import { BadRequestException, Controller, Get, Query } from '@nestjs/common';

import { InstituicoesService } from './instituicoes.service';

@Controller('instituicoes')
export class InstituicoesController {
  constructor(private readonly instituicoesService: InstituicoesService) {}

  @Get()
  async buscar(
    @Query('busca') buscaRecebida?: string,
    @Query('cidade') cidade?: string,
    @Query('uf') uf?: string,
    @Query('latitude') latitudeRecebida?: string,
    @Query('longitude') longitudeRecebida?: string,
  ) {
    const busca = buscaRecebida?.trim() ?? '';

    if (busca.length < 2 || busca.length > 100) {
      throw new BadRequestException('Digite entre 2 e 100 caracteres');
    }

    const latitude = Number(latitudeRecebida);
    const longitude = Number(longitudeRecebida);
    const instituicoes = await this.instituicoesService.buscar(
      busca,
      cidade?.trim(),
      uf?.trim(),
      Number.isFinite(latitude) ? latitude : undefined,
      Number.isFinite(longitude) ? longitude : undefined,
    );

    return {
      sucesso: true,
      dados: instituicoes.map(({ instituicao, campus, distanciaKm }) => ({
        id: instituicao.idInstituicao,
        codigoEmec: instituicao.codigoEmec,
        nome: instituicao.nome,
        sigla: instituicao.sigla,
        campus: campus.nome,
        municipio: campus.municipio,
        uf: campus.uf,
        distanciaKm,
      })),
    };
  }
}
