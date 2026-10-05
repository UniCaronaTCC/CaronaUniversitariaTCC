import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { ProgressoCaronaService } from './progresso-carona.service';
import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';

describe('Progresso da corrida', () => {
  const pontos = () =>
    [1, 2].map((id) =>
      Object.assign(new PontoEmbarque(), {
        idPontoEmbarque: id,
        ordem: id,
      }),
    );
  let service: ProgressoCaronaService;
  let caronas: { findOne: jest.Mock };
  let repository: { find: jest.Mock; save: jest.Mock };
  let solicitacoes: { exists: jest.Mock };
  beforeEach(() => {
    caronas = {
      findOne: jest.fn().mockResolvedValue({
        status: 'EM_ANDAMENTO',
        usuario: { idUsuario: 10 },
      }),
    };
    repository = {
      find: jest.fn().mockResolvedValue(pontos()),
      save: jest
        .fn()
        .mockImplementation((p: PontoEmbarque) => Promise.resolve(p)),
    };
    solicitacoes = { exists: jest.fn().mockResolvedValue(false) };
    const manager = {
      getRepository: (tipo: unknown) =>
        tipo === Carona
          ? caronas
          : tipo === PontoEmbarque
            ? repository
            : solicitacoes,
    } as unknown as EntityManager;
    service = new ProgressoCaronaService({
      manager,
      transaction: (fn: (m: EntityManager) => Promise<unknown>) => fn(manager),
    } as unknown as DataSource);
  });

  it('marca uma vez e conserva o horário em requisições repetidas', async () => {
    const primeira = await service.marcar(7, 1, 10);
    const horario = primeira[0].percorridoEm;
    const segunda = await service.marcar(7, 1, 10);
    expect(segunda[0].percorridoEm).toBe(horario);
    expect(horario).toBeInstanceOf(Date);
    expect(repository.save).toHaveBeenCalledTimes(1);
    expect(caronas.findOne).toHaveBeenCalledWith({
      where: { idCarona: 7, usuario: { idUsuario: 10 } },
      lock: { mode: 'pessimistic_write' },
    });
  });
  it('não permite pular pontos ou usar ponto de outra carona', async () => {
    await expect(service.marcar(7, 2, 10)).rejects.toBeInstanceOf(
      ConflictException,
    );
    await expect(service.marcar(7, 99, 10)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(repository.save).not.toHaveBeenCalled();
  });
  it('bloqueia motorista diferente e corrida encerrada', async () => {
    caronas.findOne.mockResolvedValueOnce(null);
    await expect(service.marcar(7, 1, 11)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    caronas.findOne.mockResolvedValueOnce({ status: 'FINALIZADA' });
    await expect(service.marcar(7, 1, 10)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(repository.save).not.toHaveBeenCalled();
  });
  it('consulta é restrita ao motorista e passageiros aceitos', async () => {
    await expect(service.consultar(7, 11)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    solicitacoes.exists.mockResolvedValue(true);
    await expect(service.consultar(7, 11)).resolves.toHaveLength(2);
    expect(solicitacoes.exists).toHaveBeenCalledWith({
      where: {
        carona: { idCarona: 7 },
        passageiro: { idUsuario: 11 },
        status: 'ACEITA',
      },
    });
  });
});
