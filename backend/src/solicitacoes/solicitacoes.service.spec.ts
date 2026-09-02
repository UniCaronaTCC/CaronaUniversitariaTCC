import { BadRequestException, ConflictException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
import { CaronasService } from '../caronas/caronas.service';
import { PontoEmbarque } from '../caronas/ponto-embarque.entity';
import { AvaliacoesService } from '../avaliacoes/avaliacoes.service';
import { Conversa } from '../mensagens/conversa.entity';
import { Solicitacao } from './solicitacao.entity';
import { SolicitacoesService } from './solicitacoes.service';

describe('SolicitacoesService', () => {
  let service: SolicitacoesService;
  let solicitacoesRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let caronasRepository: {
    findOne: jest.Mock;
  };
  let pontosEmbarqueRepository: {
    findOne: jest.Mock;
  };
  let dataSource: {
    transaction: jest.Mock;
  };
  let caronasService: {
    finalizarCaronasVencidas: jest.Mock;
  };
  let avaliacoesService: { buscarSolicitacoesAvaliadas: jest.Mock };
  let atualizarQueryBuilder: {
    update: jest.Mock;
    set: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    execute: jest.Mock;
    innerJoinAndSelect: jest.Mock;
    leftJoinAndSelect: jest.Mock;
    innerJoin: jest.Mock;
    select: jest.Mock;
    orderBy: jest.Mock;
    addOrderBy: jest.Mock;
    getMany: jest.Mock;
  };

  beforeEach(() => {
    atualizarQueryBuilder = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue(undefined),
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      innerJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([]),
    };

    solicitacoesRepository = {
      findOne: jest.fn(),
      create: jest.fn((dados: Partial<Solicitacao>) => dados as Solicitacao),
      save: jest.fn(),
      createQueryBuilder: jest.fn(
        (): typeof atualizarQueryBuilder => atualizarQueryBuilder,
      ),
    };
    caronasRepository = {
      findOne: jest.fn(),
    };
    pontosEmbarqueRepository = {
      findOne: jest.fn(),
    };
    dataSource = {
      transaction: jest.fn(),
    };
    caronasService = {
      finalizarCaronasVencidas: jest.fn().mockResolvedValue(undefined),
    };
    avaliacoesService = {
      buscarSolicitacoesAvaliadas: jest.fn().mockResolvedValue(new Set()),
    };

    service = new SolicitacoesService(
      solicitacoesRepository as unknown as Repository<Solicitacao>,
      caronasRepository as unknown as Repository<Carona>,
      pontosEmbarqueRepository as unknown as Repository<PontoEmbarque>,
      dataSource as unknown as DataSource,
      caronasService as unknown as CaronasService,
      avaliacoesService as unknown as AvaliacoesService,
    );
  });

  it('cria uma solicitação pendente para outro motorista', async () => {
    caronasRepository.findOne.mockResolvedValue({
      idCarona: 10,
      status: 'ATIVA',
      vagas: 2,
      usuario: { idUsuario: 2 },
    });
    solicitacoesRepository.findOne.mockResolvedValue(null);
    solicitacoesRepository.save.mockImplementation((dados: Solicitacao) =>
      Promise.resolve({ ...dados, idSolicitacao: 1 }),
    );

    const resultado = await service.criarSolicitacao({
      idCarona: 10,
      idPassageiro: 1,
      tipoPontoEmbarque: 'NOVO_SOLICITADO',
      localEmbarque: 'Rua A, 100',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
    });

    expect(resultado.status).toBe('PENDENTE');
    expect(caronasService.finalizarCaronasVencidas).toHaveBeenCalledTimes(1);
    expect(solicitacoesRepository.save).toHaveBeenCalledTimes(1);
  });

  it('expira pedidos pendentes de caronas finalizadas', async () => {
    await service.listarRecebidas(2);

    expect(caronasService.finalizarCaronasVencidas).toHaveBeenCalledTimes(1);
    expect(atualizarQueryBuilder.set).toHaveBeenCalledWith({
      status: 'EXPIRADA',
    });
    expect(atualizarQueryBuilder.execute).toHaveBeenCalledTimes(1);
  });

  it('impede solicitar vaga na própria carona', async () => {
    caronasRepository.findOne.mockResolvedValue({
      idCarona: 10,
      status: 'ATIVA',
      vagas: 2,
      usuario: { idUsuario: 1 },
    });

    await expect(
      service.criarSolicitacao({
        idCarona: 10,
        idPassageiro: 1,
        tipoPontoEmbarque: 'NOVO_SOLICITADO',
        localEmbarque: 'Rua A, 100',
        embarqueLatitude: -21.2,
        embarqueLongitude: -50.4,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('impede uma segunda solicitação ativa para a mesma carona', async () => {
    caronasRepository.findOne.mockResolvedValue({
      idCarona: 10,
      status: 'ATIVA',
      vagas: 2,
      usuario: { idUsuario: 2 },
    });
    solicitacoesRepository.findOne.mockResolvedValue({
      idSolicitacao: 1,
      status: 'PENDENTE',
    });

    await expect(
      service.criarSolicitacao({
        idCarona: 10,
        idPassageiro: 1,
        tipoPontoEmbarque: 'NOVO_SOLICITADO',
        localEmbarque: 'Rua A, 100',
        embarqueLatitude: -21.2,
        embarqueLongitude: -50.4,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it.each([
    { tipo: 'EXISTENTE', vagas: 2, resposta: 'ACEITA' as const },
    { tipo: 'NOVO_SOLICITADO', vagas: 2, resposta: 'ACEITA' as const },
    { tipo: 'EXISTENTE', vagas: 1, resposta: 'ACEITA' as const },
    { tipo: 'NOVO_SOLICITADO', vagas: 2, resposta: 'RECUSADA' as const },
  ])(
    '$resposta com ponto $tipo e $vagas vaga(s)',
    async ({ tipo, vagas, resposta }) => {
      const carona = {
        idCarona: 10,
        status: 'ATIVA',
        vagas,
        usuario: { idUsuario: 2 },
      };
      const pontoExistente = { idPontoEmbarque: 5 };
      const solicitacao = {
        idSolicitacao: 1,
        status: 'PENDENTE',
        tipoPontoEmbarque: tipo,
        pontoEmbarque: tipo === 'EXISTENTE' ? pontoExistente : null,
        localEmbarque: 'Rua A, 100',
        embarqueLatitude: -21.2,
        embarqueLongitude: -50.4,
        carona,
      };
      const salvarSolicitacao = jest.fn((dados: Solicitacao) =>
        Promise.resolve(dados),
      );
      const salvarCarona = jest.fn((dados: Carona) => Promise.resolve(dados));
      const salvarConversa = jest.fn((dados: Conversa) =>
        Promise.resolve(dados),
      );
      const criarConversa = jest.fn((dados: Partial<Conversa>) => dados);
      const pontosRepository = {
        count: jest.fn().mockResolvedValue(1),
        create: jest.fn((dados: Partial<PontoEmbarque>) => dados),
        save: jest.fn((dados: Partial<PontoEmbarque>) =>
          Promise.resolve({ ...dados, idPontoEmbarque: 6 }),
        ),
      };
      const queryBuilder = {
        innerJoinAndSelect: jest.fn().mockReturnThis(),
        leftJoinAndSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        setLock: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(solicitacao),
      };

      dataSource.transaction.mockImplementation(
        (executar: (manager: unknown) => Promise<Solicitacao>) =>
          executar({
            getRepository: (entidade: unknown) => {
              if (entidade === Solicitacao) {
                return {
                  createQueryBuilder: () => queryBuilder,
                  save: salvarSolicitacao,
                };
              }

              if (entidade === Conversa) {
                return {
                  findOne: jest.fn().mockResolvedValue(null),
                  create: criarConversa,
                  save: salvarConversa,
                };
              }

              if (entidade === PontoEmbarque) {
                return pontosRepository;
              }

              return { save: salvarCarona };
            },
          }),
      );

      const resultado = await service.responderSolicitacao(1, 2, resposta);

      expect(queryBuilder.leftJoinAndSelect).toHaveBeenCalledWith(
        'solicitacao.pontoEmbarque',
        'pontoEmbarque',
      );
      expect(queryBuilder.setLock).toHaveBeenCalledWith(
        'pessimistic_write',
        undefined,
        ['solicitacao', 'carona'],
      );
      expect(resultado.status).toBe(resposta);
      expect(caronasService.finalizarCaronasVencidas).toHaveBeenCalledTimes(1);
      expect(salvarSolicitacao).toHaveBeenCalledTimes(1);

      if (resposta === 'ACEITA') {
        expect(carona.vagas).toBe(vagas - 1);
        expect(carona.status).toBe(vagas === 1 ? 'LOTADA' : 'ATIVA');
        expect(salvarCarona).toHaveBeenCalledTimes(1);
        expect(criarConversa).toHaveBeenCalledWith({
          solicitacao: { idSolicitacao: 1 },
        });
        expect(salvarConversa).toHaveBeenCalledTimes(1);
      } else {
        expect(carona.vagas).toBe(vagas);
        expect(salvarCarona).not.toHaveBeenCalled();
        expect(criarConversa).not.toHaveBeenCalled();
        expect(salvarConversa).not.toHaveBeenCalled();
      }

      if (resposta === 'ACEITA' && tipo === 'NOVO_SOLICITADO') {
        expect(pontosRepository.create).toHaveBeenCalledWith({
          nome: null,
          endereco: 'Rua A, 100',
          latitude: -21.2,
          longitude: -50.4,
          ordem: 2,
          carona: { idCarona: 10 },
        });
        expect(pontosRepository.save).toHaveBeenCalledTimes(1);
        expect(resultado.pontoEmbarque?.idPontoEmbarque).toBe(6);
        expect(resultado.tipoPontoEmbarque).toBe('NOVO_SOLICITADO');
      } else {
        expect(pontosRepository.save).not.toHaveBeenCalled();
        expect(resultado.pontoEmbarque).toBe(
          tipo === 'EXISTENTE' ? pontoExistente : null,
        );
      }
    },
  );

  it('cancela uma solicitação aceita e devolve a vaga', async () => {
    const carona = {
      idCarona: 10,
      status: 'LOTADA',
      vagas: 0,
      usuario: { idUsuario: 2 },
    };
    const solicitacao = {
      idSolicitacao: 1,
      status: 'ACEITA',
      passageiro: { idUsuario: 1 },
      carona,
    };
    const salvarSolicitacao = jest.fn((dados: Solicitacao) =>
      Promise.resolve(dados),
    );
    const salvarCarona = jest.fn((dados: Carona) => Promise.resolve(dados));
    const queryBuilder = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(solicitacao),
    };

    dataSource.transaction.mockImplementation(
      (executar: (manager: unknown) => Promise<Solicitacao>) =>
        executar({
          getRepository: (entidade: unknown) =>
            entidade === Solicitacao
              ? {
                  createQueryBuilder: () => queryBuilder,
                  save: salvarSolicitacao,
                }
              : { save: salvarCarona },
        }),
    );

    const resultado = await service.cancelarSolicitacao(1, 1);

    expect(resultado.status).toBe('CANCELADA_PASSAGEIRO');
    expect(carona.vagas).toBe(1);
    expect(carona.status).toBe('ATIVA');
    expect(salvarCarona).toHaveBeenCalledTimes(1);
    expect(salvarSolicitacao).toHaveBeenCalledTimes(1);
  });
});
