import { ConflictException } from '@nestjs/common';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Carona } from './carona.entity';
import { CaronasService } from './caronas.service';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';
import { RecorrenciasService } from './recorrencias.service';
import { EncerramentoCorridasService } from './encerramento-corridas.service';
import { ExpiracaoSolicitacoesService } from '../solicitacoes/expiracao-solicitacoes.service';

describe('Partida com reservas e pagamentos', () => {
  function preparar(pendente: boolean) {
    const eventos: string[] = [];
    const carona = Object.assign(new Carona(), {
      idCarona: 7,
      usuario: { idUsuario: 10 },
      status: 'ATIVA',
      dataInicio: '2026-11-05',
      horario: '18:00:00',
      pontosEmbarque: [],
    });
    const reserva = { status: 'ACEITA', paga: !pendente };
    const pagamentoQb = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn(() => {
        eventos.push('conferir');
        return Promise.resolve(
          reserva.status === 'ACEITA' && !reserva.paga ? 1 : 0,
        );
      }),
    };
    const bloqueio = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(carona),
    };
    const repository = {
      findOne: jest.fn().mockResolvedValue(carona),
      createQueryBuilder: () => bloqueio,
      save: jest.fn((valor: Carona) => {
        eventos.push('iniciar');
        return Promise.resolve(valor);
      }),
    };
    const manager = {
      getRepository: (tipo: unknown) =>
        tipo === Carona
          ? repository
          : { createQueryBuilder: () => pagamentoQb },
    } as unknown as EntityManager;
    const expirar = jest.fn(() => {
      eventos.push('expirar');
      return Promise.resolve();
    });
    const service = new CaronasService(
      repository as unknown as Repository<Carona>,
      {} as Repository<PontoEmbarque>,
      {} as Repository<PosicaoAtualCarona>,
      {} as Repository<Solicitacao>,
      {
        manager,
        transaction: (fn: (m: EntityManager) => Promise<unknown>) =>
          fn(manager),
      } as unknown as DataSource,
      {} as UsersService,
      {} as RecorrenciasService,
      {
        encerrarVencidas: jest.fn().mockResolvedValue(undefined),
      } as unknown as EncerramentoCorridasService,
      { expirarVencidas: expirar } as unknown as ExpiracaoSolicitacoesService,
    );
    return { service, carona, reserva, expirar, repository, eventos };
  }

  const agora = new Date('2026-11-05T21:00:00Z');
  it('resolve vencidas, confere os pagamentos e só depois inicia', async () => {
    const p = preparar(false);
    await p.service.iniciarCarona(7, 10, agora);
    expect(p.eventos).toEqual(['expirar', 'conferir', 'iniciar']);
    expect(p.expirar).toHaveBeenCalledWith(7);
    expect(p.carona.status).toBe('EM_ANDAMENTO');
  });

  it('não inicia nem remove reserva cujo pagamento está pendente', async () => {
    const p = preparar(true);
    await expect(p.service.iniciarCarona(7, 10, agora)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(p.reserva.status).toBe('ACEITA');
    expect(p.carona.status).toBe('ATIVA');
    expect(p.repository.save).not.toHaveBeenCalled();
  });

  it('inicia após a expiração segura da única reserva não paga', async () => {
    const p = preparar(true);
    p.expirar.mockImplementation(() => {
      p.reserva.status = 'EXPIRADA';
      return Promise.resolve();
    });
    await expect(p.service.iniciarCarona(7, 10, agora)).resolves.toMatchObject({
      status: 'EM_ANDAMENTO',
    });
  });

  it('não dispara a expiração por pedido de outro usuário', async () => {
    const p = preparar(false);
    await expect(p.service.iniciarCarona(7, 11, agora)).rejects.toThrow(
      'Carona não encontrada',
    );
    expect(p.expirar).not.toHaveBeenCalled();
  });
});
