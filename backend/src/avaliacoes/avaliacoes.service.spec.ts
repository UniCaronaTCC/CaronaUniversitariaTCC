import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
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
        iniciadaEm: new Date('2026-11-08T12:00:00Z'),
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
        iniciadaEm: new Date('2026-11-08T12:00:00Z'),
        usuario: { idUsuario: 2 },
      },
    });
    avaliacoesRepository.findOne.mockResolvedValue({ idAvaliacao: 3 });

    await expect(service.criar(1, 10, 5, null)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  for (const idAvaliador of [1, 2]) {
    describe(`avaliador ${idAvaliador === 1 ? 'passageiro' : 'motorista'}`, () => {
      const participacao = (
        status = 'ACEITA',
        statusCarona = 'FINALIZADA',
        iniciadaEm: Date | null = new Date('2026-11-08T12:00:00Z'),
      ) => ({
        idSolicitacao: 10,
        status,
        passageiro: { idUsuario: 1 },
        carona: {
          status: statusCarona,
          iniciadaEm,
          usuario: { idUsuario: 2 },
        },
      });

      it('avalia a outra pessoa da participação, uma vez por autor', async () => {
        solicitacoesRepository.findOne.mockResolvedValue(participacao());
        // A outra pessoa já avaliou; isso não bloqueia o autor atual.
        avaliacoesRepository.findOne.mockImplementation(
          ({ where }: { where: { avaliador: { idUsuario: number } } }) =>
            Promise.resolve(
              where.avaliador.idUsuario === idAvaliador
                ? null
                : { idAvaliacao: 3 },
            ),
        );
        await service.criar(idAvaliador, 10, 4, 'Boa viagem');
        expect(avaliacoesRepository.findOne).toHaveBeenCalledWith({
          where: {
            solicitacao: { idSolicitacao: 10 },
            avaliador: { idUsuario: idAvaliador },
          },
        });
        expect(avaliacoesRepository.save).toHaveBeenCalledWith(
          expect.objectContaining({
            avaliador: { idUsuario: idAvaliador },
            avaliado: { idUsuario: idAvaliador === 1 ? 2 : 1 },
            nota: 4,
          }),
        );
      });

      it.each([
        'PENDENTE',
        'RECUSADA',
        'EXPIRADA',
        'CANCELADA_PASSAGEIRO',
        'CANCELADA_MOTORISTA',
      ])(
        'bloqueia participação %s mesmo após a finalização',
        async (status) => {
          solicitacoesRepository.findOne.mockResolvedValue(
            participacao(status),
          );
          await expect(
            service.criar(idAvaliador, 10, 5, null),
          ).rejects.toBeInstanceOf(ConflictException);
          expect(avaliacoesRepository.save).not.toHaveBeenCalled();
        },
      );

      it.each([
        'ATIVA',
        'LOTADA',
        'EM_ANDAMENTO',
        'CANCELADA',
        'EXPIRADA',
        'ENCERRADA_POR_TEMPO',
      ])('bloqueia carona %s mesmo com participação aceita', async (status) => {
        solicitacoesRepository.findOne.mockResolvedValue(
          participacao('ACEITA', status),
        );
        await expect(
          service.criar(idAvaliador, 10, 5, null),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(avaliacoesRepository.save).not.toHaveBeenCalled();
      });

      it('bloqueia oferta vencida sem corrida iniciada', async () => {
        solicitacoesRepository.findOne.mockResolvedValue(
          participacao('ACEITA', 'FINALIZADA', null),
        );
        await expect(
          service.criar(idAvaliador, 10, 5, null),
        ).rejects.toBeInstanceOf(ConflictException);
        expect(avaliacoesRepository.save).not.toHaveBeenCalled();
      });

      it('bloqueia repetição da avaliação do mesmo autor', async () => {
        solicitacoesRepository.findOne.mockResolvedValue(participacao());
        avaliacoesRepository.findOne.mockResolvedValue({ idAvaliacao: 3 });
        await expect(service.criar(idAvaliador, 10, 5, null)).rejects.toThrow(
          'Você já avaliou esta carona',
        );
        expect(avaliacoesRepository.save).not.toHaveBeenCalled();
      });
    });
  }

  it('não libera carona recorrente antiga apenas porque passou o horário', () => {
    expect(
      service.podeAvaliarSolicitacao({
        status: 'ACEITA',
        carona: {
          recorrente: true,
          status: 'ATIVA',
          dataInicio: '2020-01-01',
          horario: '12:00:00',
          diasSemana: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'],
        },
      } as Solicitacao),
    ).toBe(false);
  });

  it('não permite que um terceiro avalie a participação', async () => {
    solicitacoesRepository.findOne.mockResolvedValue({
      status: 'ACEITA',
      passageiro: { idUsuario: 1 },
      carona: {
        status: 'FINALIZADA',
        iniciadaEm: new Date('2026-11-08T12:00:00Z'),
        usuario: { idUsuario: 2 },
      },
    });
    await expect(service.criar(99, 10, 5, null)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(avaliacoesRepository.save).not.toHaveBeenCalled();
  });

  it('lista as avaliacoes recebidas com media e paginacao', async () => {
    const resultado = await service.listarRecebidas(1, 1);

    expect(resultado.media).toBe(4.5);
    expect(resultado.total).toBe(2);
    expect(resultado.totalPaginas).toBe(1);
    expect(resultado.avaliacoes).toHaveLength(2);
  });

  it.each([false, true])(
    'nao habilita avaliacao de corrida encerrada por tempo (recorrente=%s)',
    (recorrente) => {
      expect(
        service.podeAvaliarSolicitacao({
          status: 'ACEITA',
          carona: { status: 'ENCERRADA_POR_TEMPO', recorrente },
        } as Solicitacao),
      ).toBe(false);
    },
  );

  it('informa quando o usuario nao existe', async () => {
    usersService.buscarPorId.mockResolvedValue(null);

    await expect(service.listarRecebidas(99, 1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(avaliacoesRepository.createQueryBuilder).not.toHaveBeenCalled();
  });
});
