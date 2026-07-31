import { BadRequestException, ConflictException } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
import { CaronasService } from '../caronas/caronas.service';
import { Solicitacao } from './solicitacao.entity';
import { SolicitacoesService } from './solicitacoes.service';

describe('SolicitacoesService', () => {
  let service: SolicitacoesService;
  let solicitacoesRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let caronasRepository: {
    findOne: jest.Mock;
  };
  let dataSource: {
    transaction: jest.Mock;
  };
  let caronasService: {
    finalizarCaronasVencidas: jest.Mock;
  };

  beforeEach(() => {
    solicitacoesRepository = {
      findOne: jest.fn(),
      create: jest.fn((dados) => dados),
      save: jest.fn(),
    };
    caronasRepository = {
      findOne: jest.fn(),
    };
    dataSource = {
      transaction: jest.fn(),
    };
    caronasService = {
      finalizarCaronasVencidas: jest.fn().mockResolvedValue(undefined),
    };

    service = new SolicitacoesService(
      solicitacoesRepository as unknown as Repository<Solicitacao>,
      caronasRepository as unknown as Repository<Carona>,
      dataSource as unknown as DataSource,
      caronasService as unknown as CaronasService,
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
    solicitacoesRepository.save.mockImplementation(async (dados) => ({
      ...dados,
      idSolicitacao: 1,
    }));

    const resultado = await service.criarSolicitacao({
      idCarona: 10,
      idPassageiro: 1,
      localEmbarque: 'Rua A, 100',
      embarqueLatitude: -21.2,
      embarqueLongitude: -50.4,
    });

    expect(resultado.status).toBe('PENDENTE');
    expect(caronasService.finalizarCaronasVencidas).toHaveBeenCalledTimes(1);
    expect(solicitacoesRepository.save).toHaveBeenCalledTimes(1);
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
        localEmbarque: 'Rua A, 100',
        embarqueLatitude: -21.2,
        embarqueLongitude: -50.4,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('aceita uma solicitação e desconta uma vaga', async () => {
    const carona = {
      idCarona: 10,
      status: 'ATIVA',
      vagas: 2,
      usuario: { idUsuario: 2 },
    };
    const solicitacao = {
      idSolicitacao: 1,
      status: 'PENDENTE',
      carona,
    };
    const salvarSolicitacao = jest.fn(async (dados) => dados);
    const salvarCarona = jest.fn(async (dados) => dados);
    const queryBuilder = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(solicitacao),
    };

    dataSource.transaction.mockImplementation(async (executar) =>
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

    const resultado = await service.responderSolicitacao(1, 2, 'ACEITA');

    expect(resultado.status).toBe('ACEITA');
    expect(caronasService.finalizarCaronasVencidas).toHaveBeenCalledTimes(1);
    expect(carona.vagas).toBe(1);
    expect(salvarCarona).toHaveBeenCalledTimes(1);
    expect(salvarSolicitacao).toHaveBeenCalledTimes(1);
  });
});
