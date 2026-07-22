import { BadRequestException, ConflictException } from '@nestjs/common';
import { Repository } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
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

  beforeEach(() => {
    solicitacoesRepository = {
      findOne: jest.fn(),
      create: jest.fn((dados) => dados),
      save: jest.fn(),
    };
    caronasRepository = {
      findOne: jest.fn(),
    };

    service = new SolicitacoesService(
      solicitacoesRepository as unknown as Repository<Solicitacao>,
      caronasRepository as unknown as Repository<Carona>,
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
});
