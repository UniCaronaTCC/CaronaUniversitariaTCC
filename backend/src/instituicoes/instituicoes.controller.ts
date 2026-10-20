import { BadRequestException, Controller, Get, Query } from '@nestjs/common';

import { InstituicoesService } from './instituicoes.service';

@Controller('instituicoes')
export class InstituicoesController {
  constructor(private readonly instituicoesService: InstituicoesService) {}

  @Get('destinos')
  async listarDestinos(
    @Query('cidade') cidadeRecebida?: string,
    @Query('uf') ufRecebida?: string,
  ) {
    const cidade =
      typeof cidadeRecebida === 'string'
        ? cidadeRecebida.trim().replace(/\s+/g, ' ')
        : '';
    const uf =
      typeof ufRecebida === 'string' ? ufRecebida.trim().toUpperCase() : '';
    const ufs = new Set([
      'AC',
      'AL',
      'AP',
      'AM',
      'BA',
      'CE',
      'DF',
      'ES',
      'GO',
      'MA',
      'MT',
      'MS',
      'MG',
      'PA',
      'PB',
      'PR',
      'PE',
      'PI',
      'RJ',
      'RN',
      'RS',
      'RO',
      'RR',
      'SC',
      'SP',
      'SE',
      'TO',
    ]);
    if (cidade.length < 2 || cidade.length > 100 || !ufs.has(uf)) {
      throw new BadRequestException('Informe uma cidade e uma UF válidas');
    }
    return {
      sucesso: true,
      dados: await this.instituicoesService.listarDestinos(cidade, uf),
    };
  }

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
