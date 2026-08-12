import { ConflictException, NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';

import { CaronasService } from '../caronas/caronas.service';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';
import { Avaliacao } from './avaliacao.entity';
import { AvaliacoesService } from './avaliacoes.service';

describe('AvaliacoesService', () => {
  let service: AvaliacoesService;
  let avaliacoesRepository: {
    createQueryBuilder: jest.Mock;
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let solicitacoesRepository: { findOne: jest.Mock };
  let usersService: { buscarPorId: jest.Mock };
  let caronasService: { finalizarCaronasVencidas: jest.Mock };

  beforeEach(() => {
    const resumoQuery = {
      select: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getRawOne: jest.fn().mockResolvedValue({ media: '4.50', total: '2' }),
    };

    const listaQuery = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([
        { idAvaliacao: 1, nota: 5 },
        { idAvaliacao: 2, nota: 4 },
      ]),
    };

    avaliacoesRepository = {
      createQueryBuilder: jest
        .fn()
        .mockReturnValueOnce(resumoQuery)
        .mockReturnValueOnce(listaQuery),
      findOne: jest.fn(),
      create: jest.fn((dados: Partial<Avaliacao>) => dados as Avaliacao),
      save: jest.fn((dados: Avaliacao) =>
        Promise.resolve({ ...dados, idAvaliacao: 1 }),
      ),
    };
    solicitacoesRepository = { findOne: jest.fn() };
    usersService = {
      buscarPorId: jest.fn().mockResolvedValue({ idUsuario: 1 }),
    };
    caronasService = {
      finalizarCaronasVencidas: jest.fn().mockResolvedValue(undefined),
    };

    service = new AvaliacoesService(
      avaliacoesRepository as unknown as Repository<Avaliacao>,
      solicitacoesRepository as unknown as Repository<Solicitacao>,
      usersService as unknown as UsersService,
      caronasService as unknown as CaronasService,
    );
  });

  it('permite que o passageiro avalie o motorista após a carona', async () => {
    solicitacoesRepository.findOne.mockResolvedValue({
      idSolicitacao: 10,
      status: 'ACEITA',
      passageiro: { idUsuario: 1 },
      carona: {
        status: 'FINALIZADA',
        usuario: { idUsuario: 2 },
      },
    });
    avaliacoesRepository.findOne.mockResolvedValue(null);

    await service.criar(1, 10, 5, 'Muito bom');

    expect(avaliacoesRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        avaliador: { idUsuario: 1 },
        avaliado: { idUsuario: 2 },
        nota: 5,
      }),
    );
  });

  it('não permite avaliar antes da carona terminar', async () => {
    solicitacoesRepository.findOne.mockResolvedValue({
      idSolicitacao: 10,
      status: 'ACEITA',
      passageiro: { idUsuario: 1 },
      carona: { status: 'ATIVA', usuario: { idUsuario: 2 } },
    });

    await expect(service.criar(1, 10, 5, null)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(avaliacoesRepository.save).not.toHaveBeenCalled();
  });

  it('não permite avaliar duas vezes a mesma carona', async () => {
    solicitacoesRepository.findOne.mockResolvedValue({
      idSolicitacao: 10,
      status: 'ACEITA',
      passageiro: { idUsuario: 1 },
      carona: {
        status: 'FINALIZADA',
        usuario: { idUsuario: 2 },
      },
    });
    avaliacoesRepository.findOne.mockResolvedValue({ idAvaliacao: 3 });

    await expect(service.criar(1, 10, 5, null)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('libera avaliação recorrente depois da primeira ocorrência', () => {
    const solicitacao = {
      status: 'ACEITA',
      criadoEm: new Date(2026, 7, 10, 8),
      atualizadoEm: new Date(2026, 7, 10, 8),
      carona: {
        recorrente: true,
        dataInicio: '2026-08-10',
        dataFim: null,
        horario: '19:00:00',
        diasSemana: ['SEG'],
      },
    } as Solicitacao;

    expect(
      service.podeAvaliarSolicitacao(solicitacao, new Date(2026, 7, 10, 20)),
    ).toBe(true);
  });

  it('mantém avaliação recorrente bloqueada antes da primeira ocorrência', () => {
    const solicitacao = {
      status: 'ACEITA',
      criadoEm: new Date(2026, 7, 10, 8),
      atualizadoEm: new Date(2026, 7, 10, 8),
      carona: {
        recorrente: true,
        dataInicio: '2026-08-10',
        dataFim: null,
        horario: '19:00:00',
        diasSemana: ['SEG'],
      },
    } as Solicitacao;

    expect(
      service.podeAvaliarSolicitacao(solicitacao, new Date(2026, 7, 10, 18)),
    ).toBe(false);
  });

  it('lista as avaliacoes recebidas com media e paginacao', async () => {
    const resultado = await service.listarRecebidas(1, 1);

    expect(resultado.media).toBe(4.5);
    expect(resultado.total).toBe(2);
    expect(resultado.totalPaginas).toBe(1);
    expect(resultado.avaliacoes).toHaveLength(2);
  });

  it('informa quando o usuario nao existe', async () => {
    usersService.buscarPorId.mockResolvedValue(null);

    await expect(service.listarRecebidas(99, 1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(avaliacoesRepository.createQueryBuilder).not.toHaveBeenCalled();
  });
});
