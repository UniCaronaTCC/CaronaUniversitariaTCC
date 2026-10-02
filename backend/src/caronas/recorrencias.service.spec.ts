import { DataSource, EntityManager } from 'typeorm';
import { RecorrenciasService } from './recorrencias.service';
import { RecorrenciasController } from './recorrencias.controller';
import { RecorrenciaCarona } from './recorrencia.entity';
import { PontoEmbarqueRecorrencia } from './ponto-embarque-recorrencia.entity';
import { Carona } from './carona.entity';
import type { DadosCriacaoCarona } from './caronas.service';

describe('Recorrências', () => {
  const dados: DadosCriacaoCarona = {
    idUsuario: 1,
    origem: 'Rua A, 10',
    origemCidade: 'Araçatuba',
    origemLatitude: -21.2,
    origemLongitude: -50.4,
    destino: 'Faculdade',
    destinoCidade: 'Araçatuba',
    destinoLatitude: -21.19,
    destinoLongitude: -50.43,
    dataInicio: '2026-09-28',
    dataFim: null,
    horario: '18:00:00',
    vagas: 3,
    valor: 5,
    recorrente: true,
    diasSemana: ['SEG', 'TER'],
    pontosEmbarque: [
      {
        nome: null,
        endereco: 'Rua B',
        latitude: -21.2,
        longitude: -50.4,
        ordem: 1,
      },
    ],
  };
  let service: RecorrenciasService;
  let modelo: RecorrenciaCarona;
  let caronas: Carona[];
  let modelosRepository: {
    find: jest.Mock;
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };

  beforeEach(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-09-26T15:00:00Z'));
    caronas = [];
    const { idUsuario, ...configuracao } = structuredClone(dados);
    modelo = Object.assign(new RecorrenciaCarona(), {
      idRecorrencia: 7,
      idUsuario,
    });
    modelo.definirDados(configuracao);
    modelosRepository = {
      find: jest.fn(() => Promise.resolve([modelo])),
      findOne: jest.fn(({ where }: { where: { idUsuario?: number } }) =>
        Promise.resolve(
          where.idUsuario !== undefined && where.idUsuario !== modelo.idUsuario
            ? null
            : modelo,
        ),
      ),
      create: jest.fn((value: Partial<RecorrenciaCarona>) =>
        Object.assign(new RecorrenciaCarona(), value),
      ),
      save: jest.fn((value: Partial<RecorrenciaCarona>) =>
        Promise.resolve(
          Object.assign(modelo, Object.assign(value, { idRecorrencia: 7 })),
        ),
      ),
    };
    const repository = {
      exists: jest.fn(({ where }: { where: { dataOcorrencia: string } }) =>
        Promise.resolve(
          caronas.some((c) => c.dataOcorrencia === where.dataOcorrencia),
        ),
      ),
      create: jest.fn((value: Partial<Carona>) => value as Carona),
      save: jest.fn((value: Carona) => {
        const carona = { ...value, idCarona: caronas.length + 1 };
        caronas.push(carona);
        return Promise.resolve(carona);
      }),
      findOneOrFail: jest.fn(() => Promise.resolve(caronas[0])),
    };
    const pontosRepository = {
      find: jest.fn(() => Promise.resolve(modelo.pontosEmbarque)),
      delete: jest.fn(() => Promise.resolve({ affected: 1 })),
    };
    const getRepository = (tipo: unknown) =>
      tipo === RecorrenciaCarona
        ? modelosRepository
        : tipo === PontoEmbarqueRecorrencia
          ? pontosRepository
          : repository;
    const manager = { getRepository } as unknown as EntityManager;
    service = new RecorrenciasService({
      getRepository,
      transaction: (executar: (m: EntityManager) => Promise<unknown>) =>
        executar(manager),
    } as unknown as DataSource);
  });
  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  it('cria IDs distintos e copia somente a oferta e os pontos para cada data', async () => {
    await service.criar(dados);
    expect(caronas).toHaveLength(4);
    expect(new Set(caronas.map((c) => c.idCarona)).size).toBe(4);
    expect(
      caronas.every(
        (c) => !c.recorrente && c.vagas === 3 && c.status === 'ATIVA',
      ),
    ).toBe(true);
    expect(caronas[0].pontosEmbarque).not.toBe(caronas[1].pontosEmbarque);
    expect(caronas[0].pontosEmbarque[0]).not.toHaveProperty('idPontoEmbarque');
    expect(caronas[0]).not.toHaveProperty('solicitacoes');
  });
  it('mantém o contrato do aplicativo ao carregar colunas e pontos separados', async () => {
    const resposta = await new RecorrenciasController(service).listar({
      usuario: { sub: 1 },
    } as never);
    expect(resposta.dados[0]).toMatchObject({
      idRecorrencia: 7,
      ativa: true,
      dados: {
        origem: dados.origem,
        diasSemana: ['SEG', 'TER'],
        pontosEmbarque: dados.pontosEmbarque,
      },
    });
    expect(modelosRepository.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { idUsuario: 1 },
        relations: { pontosEmbarque: true },
      }),
    );
  });
  it('reexecução preserva corridas canceladas, vagas e partidas em andamento', async () => {
    await service.criar(dados);
    caronas[0].status = 'CANCELADA';
    caronas[1].status = 'EM_ANDAMENTO';
    caronas[1].vagas = 1;
    await service.completarProgramacoes();
    expect(caronas).toHaveLength(4);
    expect(caronas[0].status).toBe('CANCELADA');
    expect(caronas[1].vagas).toBe(1);
  });
  it('pausa geração e retoma sem duplicar corridas existentes', async () => {
    await service.criar(dados);
    await service.atualizar(7, 1, undefined, false);
    jest.setSystemTime(new Date('2026-10-05T12:00:00Z'));
    await service.completarProgramacoes();
    expect(caronas).toHaveLength(4);
    await service.atualizar(7, 1, undefined, true);
    expect(caronas).toHaveLength(6);
  });
  it('edição conserva publicações anteriores e altera somente novas datas', async () => {
    await service.criar(dados);
    await service.atualizar(7, 1, { ...dados, valor: 9 });
    expect(caronas.every((c) => c.valor === 5)).toBe(true);
    jest.setSystemTime(new Date('2026-10-05T12:00:00Z'));
    await service.completarProgramacoes();
    expect(caronas.slice(4).every((c) => c.valor === 9)).toBe(true);
  });
  it('alterar pontos da programação preserva os pontos das caronas já geradas', async () => {
    await service.criar(dados);
    await service.atualizar(7, 1, {
      ...dados,
      diasSemana: ['DOM', 'SEG'],
      pontosEmbarque: [{ ...dados.pontosEmbarque[0], endereco: 'Novo ponto' }],
    });
    expect(modelo.diasSemana).toEqual([7, 1]);
    expect(modelo.dados.diasSemana).toEqual(['DOM', 'SEG']);
    expect(
      caronas
        .slice(0, 4)
        .every((c) => c.pontosEmbarque[0].endereco === 'Rua B'),
    ).toBe(true);
    expect(modelo.pontosEmbarque[0].endereco).toBe('Novo ponto');
    jest.setSystemTime(new Date('2026-10-05T12:00:00Z'));
    await service.completarProgramacoes();
    expect(caronas.at(-1)?.pontosEmbarque[0].endereco).toBe('Novo ponto');
  });
  it('não permite editar ou pausar programação de outro motorista', async () => {
    await expect(service.atualizar(7, 2, dados)).rejects.toThrow(
      'Recorrência não encontrada',
    );
    await expect(service.atualizar(7, 2, undefined, false)).rejects.toThrow(
      'Recorrência não encontrada',
    );
    expect(modelosRepository.save).not.toHaveBeenCalled();
  });
  it('não aceita nova programação sem partidas futuras', async () => {
    await expect(
      service.criar({ ...dados, dataFim: '2026-09-27' }),
    ).rejects.toThrow('Selecione dias');
  });
});
