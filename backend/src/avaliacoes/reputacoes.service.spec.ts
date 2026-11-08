import { Logger } from '@nestjs/common';
import { Repository } from 'typeorm';
import { Avaliacao } from './avaliacao.entity';
import { ReputacoesService } from './reputacoes.service';

describe('ReputacoesService (somente leitura, sem banco real)', () => {
  const consulta = {
    select: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    getRawMany: jest.fn(),
  };
  const repositorio = { createQueryBuilder: jest.fn(() => consulta) };
  const servico = new ReputacoesService(
    repositorio as unknown as Repository<Avaliacao>,
  );
  let aviso: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    consulta.getRawMany.mockResolvedValue([]);
    aviso = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => {});
  });
  afterEach(() => aviso.mockRestore());

  it.each([{ ids: [] }, { ids: [0, -1, NaN, Infinity, 1.5] }])(
    'nao consulta o banco sem identificadores validos: %j',
    async ({ ids }) => {
      expect(await servico.buscarResumos(ids)).toEqual(new Map());
      expect(repositorio.createQueryBuilder).not.toHaveBeenCalled();
    },
  );

  it('deduplica os usuarios e agrega todas as notas recebidas em uma consulta', async () => {
    consulta.getRawMany.mockResolvedValue([
      { idUsuario: '8', media: '4.6666666667', total: '3' },
      { idUsuario: '9', media: '1', total: '1' },
    ]);
    const resumos = await servico.buscarResumos([8, 8, 9, 10, 0, -1, 1.5]);
    expect(resumos).toEqual(
      new Map([
        [8, { media: 4.67, total: 3 }],
        [9, { media: 1, total: 1 }],
        [10, { media: 0, total: 0 }],
      ]),
    );
    expect(repositorio.createQueryBuilder).toHaveBeenCalledTimes(1);
    expect(consulta.getRawMany).toHaveBeenCalledTimes(1);
    expect(consulta.select).toHaveBeenCalledWith(
      'avaliacao.id_avaliado',
      'idUsuario',
    );
    expect(consulta.addSelect).toHaveBeenCalledWith(
      'AVG(avaliacao.nota)',
      'media',
    );
    expect(consulta.addSelect).toHaveBeenCalledWith('COUNT(*)', 'total');
    expect(consulta.where).toHaveBeenCalledWith(
      'avaliacao.id_avaliado IN (:...idsUsuarios)',
      { idsUsuarios: [8, 9, 10] },
    );
    expect(consulta.groupBy).toHaveBeenCalledWith('avaliacao.id_avaliado');
  });

  it('mantem uma consulta para uma lista grande com motoristas repetidos', async () => {
    const ids = Array.from({ length: 500 }, (_, indice) => (indice % 20) + 1);
    expect((await servico.buscarResumos(ids)).size).toBe(20);
    expect(consulta.getRawMany).toHaveBeenCalledTimes(1);
  });

  it('distingue falha de consulta de ausencia confirmada de avaliacoes', async () => {
    expect((await servico.buscarResumos([8])).get(8)).toEqual({
      media: 0,
      total: 0,
    });
    consulta.getRawMany.mockRejectedValueOnce(new Error('detalhes privados'));
    expect((await servico.buscarResumos([8])).has(8)).toBe(false);
    expect(aviso).toHaveBeenCalledWith(
      'Nao foi possivel consultar os resumos de reputacao',
    );
    expect(aviso).not.toHaveBeenCalledWith(expect.stringContaining('privados'));
  });

  it.each([
    { idUsuario: 8, media: 'NaN', total: '1' },
    { idUsuario: 8, media: '6', total: '1' },
    { idUsuario: 8, media: '0', total: '1' },
    { idUsuario: 8, media: '4', total: '1.5' },
    { idUsuario: 99, media: '4', total: '1' },
  ])('nao publica resumo inconsistente: %j', async (registro) => {
    consulta.getRawMany.mockResolvedValue([registro]);
    expect(await servico.buscarResumos([8])).toEqual(new Map());
  });

  it('consulta os dados atuais sem cache global entre requisicoes', async () => {
    consulta.getRawMany.mockResolvedValueOnce([
      { idUsuario: 8, media: '5', total: '1' },
    ]);
    consulta.getRawMany.mockResolvedValueOnce([
      { idUsuario: 8, media: '4', total: '2' },
    ]);
    expect((await servico.buscarResumos([8])).get(8)?.media).toBe(5);
    expect((await servico.buscarResumos([8])).get(8)).toEqual({
      media: 4,
      total: 2,
    });
  });
});
