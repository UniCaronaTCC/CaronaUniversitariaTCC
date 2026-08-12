import { Repository } from 'typeorm';

import { Instituicao } from './instituicao.entity';
import { InstituicoesService } from './instituicoes.service';

describe('InstituicoesService', () => {
  it('busca instituições ativas por nome ou sigla', async () => {
    const resultadoEsperado = [
      {
        idInstituicao: 1,
        codigoEmec: 123,
        nome: 'Centro Universitário Salesiano',
        sigla: 'UNISALESIANO',
        municipio: 'Araçatuba',
        uf: 'SP',
        ativa: true,
      },
    ] as Instituicao[];
    const repository = {
      find: jest.fn().mockResolvedValue(resultadoEsperado),
    };
    const service = new InstituicoesService(
      repository as unknown as Repository<Instituicao>,
    );

    const resultado = await service.buscar('unisalesiano');

    expect(resultado).toEqual(resultadoEsperado);
    expect(repository.find).toHaveBeenCalledTimes(1);
  });

  it('não consulta o banco quando a busca fica vazia', async () => {
    const repository = { find: jest.fn() };
    const service = new InstituicoesService(
      repository as unknown as Repository<Instituicao>,
    );

    const resultado = await service.buscar('%_');

    expect(resultado).toEqual([]);
    expect(repository.find).not.toHaveBeenCalled();
  });
});
