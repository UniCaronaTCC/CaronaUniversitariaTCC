import { BadRequestException } from '@nestjs/common';
import { FindOperator, FindOptionsWhere, Repository } from 'typeorm';
import { InstituicaoCampus } from './instituicao-campus.entity';
import { Instituicao } from './instituicao.entity';
import { InstituicoesController } from './instituicoes.controller';
import { InstituicoesService } from './instituicoes.service';

describe('Destinos de campus', () => {
  const instituicao = {
    idInstituicao: 1,
    nome: 'Universidade Estadual',
    sigla: 'UE',
    ativa: true,
    municipio: 'São Paulo',
    uf: 'SP',
  } as Instituicao;
  const campus = {
    idCampus: 10,
    idInstituicao: 1,
    nome: 'Odontologia',
    municipio: 'Araçatuba',
    uf: 'SP',
    latitude: '-21.2',
    longitude: '-50.4',
    ativo: true,
  } as InstituicaoCampus;

  function criar(
    campi: InstituicaoCampus[] = [campus],
    instituicoes = [instituicao],
  ) {
    const repositorioCampi = {
      find: jest
        .fn<
          ReturnType<Repository<InstituicaoCampus>['find']>,
          Parameters<Repository<InstituicaoCampus>['find']>
        >()
        .mockResolvedValue(campi),
    };
    const repositorioInstituicoes = {
      find: jest
        .fn<
          ReturnType<Repository<Instituicao>['find']>,
          Parameters<Repository<Instituicao>['find']>
        >()
        .mockResolvedValue(instituicoes),
    };
    const service = new InstituicoesService(
      repositorioInstituicoes as unknown as Repository<Instituicao>,
      repositorioCampi as unknown as Repository<InstituicaoCampus>,
    );
    return { service, repositorioCampi, repositorioInstituicoes };
  }

  it('lista sem termo digitado e preserva o identificador de cada campus', async () => {
    const { service } = criar([
      campus,
      { ...campus, idCampus: 11, nome: 'Veterinária' },
    ]);
    const resultado = await service.listarDestinos('Araçatuba', 'SP');
    expect(resultado.map((item) => item.idCampus)).toEqual([10, 11]);
    expect(resultado[0]).toMatchObject({
      idInstituicao: 1,
      municipio: 'Araçatuba',
      uf: 'SP',
      latitude: -21.2,
      longitude: -50.4,
    });
  });

  it('filtra pelo municipio do campus e UF, sem depender da sede da instituição', async () => {
    const { service, repositorioCampi, repositorioInstituicoes } = criar();
    await service.listarDestinos('  ARACATUBA  ', 'SP');
    const where = repositorioCampi.find.mock.calls[0][0]!
      .where as FindOptionsWhere<InstituicaoCampus>;
    expect(where).toMatchObject({ ativo: true, uf: 'SP' });
    expect(where.municipio).toBeInstanceOf(FindOperator);
    if (!(where.municipio instanceof FindOperator))
      throw new Error('Filtro Raw ausente');
    expect(where.municipio.objectLiteralParameters).toEqual({
      cidade: 'aracatuba',
    });
    expect(where.municipio.getSql?.('campus.municipio')).toContain(
      'translate(lower(trim(campus.municipio))',
    );
    expect(repositorioInstituicoes.find.mock.calls[0][0]!.where).toMatchObject({
      ativa: true,
    });
  });

  it('mantém campus sem coordenadas, sem inventar um ponto', async () => {
    const { service } = criar([{ ...campus, latitude: null, longitude: null }]);
    expect((await service.listarDestinos('Araçatuba', 'SP'))[0]).toMatchObject({
      latitude: null,
      longitude: null,
    });
  });

  for (const valores of [
    { latitude: '91', longitude: '-50' },
    { latitude: '-21', longitude: '181' },
    { latitude: 'NaN', longitude: '-50' },
    { latitude: null, longitude: '-50' },
  ]) {
    it(`não devolve coordenadas inválidas ${JSON.stringify(valores)}`, async () => {
      const { service } = criar([{ ...campus, ...valores }]);
      expect(
        (await service.listarDestinos('Araçatuba', 'SP'))[0],
      ).toMatchObject({
        latitude: null,
        longitude: null,
      });
    });
  }

  it('não inclui instituições inativas e evita consultar ids quando não há campi', async () => {
    const { service } = criar([campus], []);
    expect(await service.listarDestinos('Araçatuba', 'SP')).toEqual([]);
    const vazio = criar([]);
    expect(await vazio.service.listarDestinos('Outra cidade', 'AM')).toEqual(
      [],
    );
    expect(vazio.repositorioInstituicoes.find).not.toHaveBeenCalled();
  });

  it('ordena por instituição e campus de forma determinística, sem truncar em dez', async () => {
    const campi = Array.from({ length: 15 }, (_, i) => ({
      ...campus,
      idCampus: i + 1,
      nome: String(i).padStart(2, '0'),
    })).reverse();
    const { service } = criar(campi);
    const resultado = await service.listarDestinos('São Paulo', 'SP');
    expect(resultado).toHaveLength(15);
    expect(resultado[0].campus).toBe('00');
    expect(resultado[14].campus).toBe('14');
  });

  it('parametriza a cidade, inclusive caracteres especiais, sem interpolar o valor no SQL', async () => {
    const { service, repositorioCampi } = criar();
    await service.listarDestinos("Sant'Ana %_", 'RS');
    const where = repositorioCampi.find.mock.calls[0][0]!
      .where as FindOptionsWhere<InstituicaoCampus>;
    const filtro = where.municipio;
    if (!(filtro instanceof FindOperator))
      throw new Error('Filtro Raw ausente');
    expect(filtro.getSql?.('municipio')).not.toContain("Sant'Ana");
    expect(filtro.objectLiteralParameters).toEqual({ cidade: "sant'ana %_" });
  });

  describe('validação HTTP', () => {
    const service = { listarDestinos: jest.fn().mockResolvedValue([]) };
    const controller = new InstituicoesController(
      service as unknown as InstituicoesService,
    );
    beforeEach(() => service.listarDestinos.mockClear());

    it('aceita a cidade sem busca e normaliza espaços e UF', async () => {
      expect(
        await controller.listarDestinos('  São   Paulo  ', ' sp '),
      ).toEqual({ sucesso: true, dados: [] });
      expect(service.listarDestinos).toHaveBeenCalledWith('São Paulo', 'SP');
    });
    for (const [cidade, uf] of [
      [undefined, 'SP'],
      ['', 'SP'],
      ['A', 'SP'],
      ['a'.repeat(101), 'SP'],
      ['Araçatuba', undefined],
      ['Araçatuba', 'XX'],
      ['Araçatuba', 'São Paulo'],
    ]) {
      it(`rejeita cidade/UF inválidas ${String(cidade).slice(0, 20)} / ${uf}`, async () => {
        await expect(
          controller.listarDestinos(cidade, uf),
        ).rejects.toBeInstanceOf(BadRequestException);
        expect(service.listarDestinos).not.toHaveBeenCalled();
      });
    }
    it('aceita todos os 27 estados, sem fixar Araçatuba no código', async () => {
      for (const uf of [
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
      ]) {
        await controller.listarDestinos('Cidade', uf);
      }
      expect(service.listarDestinos).toHaveBeenCalledTimes(27);
    });
    it('rejeita parâmetros repetidos em forma de array sem erro interno', async () => {
      await expect(
        controller.listarDestinos(['A', 'B'] as unknown as string, 'SP'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });
});
