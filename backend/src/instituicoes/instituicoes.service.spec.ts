import { Repository } from 'typeorm';

import { InstituicaoCampus } from './instituicao-campus.entity';
import { Instituicao } from './instituicao.entity';
import { InstituicoesService } from './instituicoes.service';

describe('InstituicoesService', () => {
  const instituicao = {
    idInstituicao: 1,
    codigoEmec: 4522,
    nome: 'Centro Universitário Católico Salesiano Auxilium',
    sigla: 'UNISALESIANO',
    municipio: 'Lins',
    uf: 'SP',
    ativa: true,
  } as Instituicao;

  const campusAracatuba = {
    idCampus: 1,
    idInstituicao: 1,
    nome: 'Araçatuba',
    municipio: 'Araçatuba',
    uf: 'SP',
    latitude: '-21.20890000',
    longitude: '-50.43280000',
    ativo: true,
  } as InstituicaoCampus;

  function criarService(
    instituicoesRepository: Record<string, jest.Mock>,
    campiRepository: Record<string, jest.Mock> = {},
  ) {
    return new InstituicoesService(
      instituicoesRepository as unknown as Repository<Instituicao>,
      {
        find: jest.fn().mockResolvedValue([campusAracatuba]),
        findOne: jest.fn(),
        create: jest.fn((dados) => dados),
        ...campiRepository,
      } as unknown as Repository<InstituicaoCampus>,
    );
  }

  it('busca instituições ativas por nome ou sigla', async () => {
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn().mockResolvedValue([instituicao]),
    };
    const service = criarService(repository);

    const resultado = await service.buscar('unisalesiano');

    expect(resultado).toEqual([
      {
        instituicao,
        campus: campusAracatuba,
        distanciaKm: null,
      },
    ]);
    expect(repository.find).toHaveBeenCalledTimes(1);
  });

  it('não consulta o banco quando a busca fica vazia', async () => {
    const repository = { find: jest.fn(), findOne: jest.fn() };
    const campiRepository = { find: jest.fn() };
    const service = criarService(repository, campiRepository);

    const resultado = await service.buscar('%_');

    expect(resultado).toEqual([]);
    expect(repository.find).not.toHaveBeenCalled();
    expect(repository.findOne).not.toHaveBeenCalled();
    expect(campiRepository.find).not.toHaveBeenCalled();
  });

  it('coloca o campus da cidade do usuário no início', async () => {
    const campusLins = {
      ...campusAracatuba,
      idCampus: 2,
      nome: 'Lins',
      municipio: 'Lins',
      latitude: null,
      longitude: null,
    } as InstituicaoCampus;
    const repository = {
      findOne: jest.fn().mockResolvedValue(instituicao),
      find: jest.fn().mockResolvedValue([instituicao]),
    };
    const service = criarService(repository, {
      find: jest.fn().mockResolvedValue([campusLins, campusAracatuba]),
    });

    const resultado = await service.buscar(
      'unisalesiano',
      'Araçatuba',
      'SP',
      -21.2,
      -50.43,
    );

    expect(resultado[0].campus.nome).toBe('Araçatuba');
    expect(resultado[0].distanciaKm).not.toBeNull();
  });

  it('busca uma instituição ativa pelo id', async () => {
    const repository = {
      findOne: jest.fn().mockResolvedValue(instituicao),
    };
    const service = criarService(repository);

    const resultado = await service.buscarPorId(1);

    expect(resultado).toBe(instituicao);
    expect(repository.findOne).toHaveBeenCalledWith({
      where: { idInstituicao: 1, ativa: true },
    });
  });

  it('confere se o campus pertence à instituição', async () => {
    const repository = { findOne: jest.fn() };
    const campiRepository = {
      findOne: jest.fn().mockResolvedValue(campusAracatuba),
    };
    const service = criarService(repository, campiRepository);

    const resultado = await service.campusValido(1, 'Araçatuba');

    expect(resultado).toBe(true);
    expect(campiRepository.findOne).toHaveBeenCalledWith({
      where: {
        idInstituicao: 1,
        nome: 'Araçatuba',
        ativo: true,
      },
    });
  });
});
