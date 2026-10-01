import { DataSource } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
import { AbacatePayService } from '../pagamentos/abacatepay.service';
import { Pagamento } from '../pagamentos/pagamento.entity';
import { ExpiracaoSolicitacoesService } from './expiracao-solicitacoes.service';
import { Solicitacao } from './solicitacao.entity';

describe('ExpiracaoSolicitacoesService', () => {
  let service: ExpiracaoSolicitacoesService;
  let solicitacao: Solicitacao;
  let pagamentos: Pagamento[];
  let consultarPix: jest.Mock;
  let transaction: jest.Mock;
  let salvarSolicitacao: jest.Mock;
  let salvarCarona: jest.Mock;
  let salvarPagamento: jest.Mock;

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-09-15T12:00:00.000Z'));

    solicitacao = {
      idSolicitacao: 7,
      status: 'ACEITA',
      pagamentoLimiteEm: new Date('2026-09-15T11:59:00.000Z'),
      carona: { idCarona: 4, vagas: 0, status: 'LOTADA' },
    } as Solicitacao;
    pagamentos = [];
    consultarPix = jest.fn();
    salvarSolicitacao = jest.fn((valor: Solicitacao) => Promise.resolve(valor));
    salvarCarona = jest.fn((valor: Carona) => Promise.resolve(valor));
    salvarPagamento = jest.fn((valor: Pagamento) => Promise.resolve(valor));

    const consultaSolicitacao = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn(() => Promise.resolve(solicitacao)),
    };
    const consultaPagamentos = {
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getMany: jest.fn(() => Promise.resolve(pagamentos)),
    };
    const manager = {
      getRepository: (entidade: unknown) => {
        if (entidade === Solicitacao) {
          return {
            createQueryBuilder: () => consultaSolicitacao,
            save: salvarSolicitacao,
          };
        }
        if (entidade === Carona) return { save: salvarCarona };
        return {
          createQueryBuilder: () => consultaPagamentos,
          save: salvarPagamento,
        };
      },
    };
    transaction = jest.fn((executar: (manager: unknown) => Promise<unknown>) =>
      executar(manager),
    );

    service = new ExpiracaoSolicitacoesService(
      {
        query: jest.fn().mockResolvedValue([{ id_solicitacao: 7 }]),
        getRepository: () => ({
          find: jest.fn(() => Promise.resolve(pagamentos)),
        }),
        transaction,
      } as unknown as DataSource,
      { consultarPix } as unknown as AbacatePayService,
    );
  });

  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  it('verifica ao iniciar e a cada trinta segundos, ate ser encerrado', () => {
    const verificar = jest
      .spyOn(service, 'expirarVencidas')
      .mockResolvedValue();

    service.onModuleInit();
    expect(verificar).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(30_000);
    expect(verificar).toHaveBeenCalledTimes(2);

    service.onModuleDestroy();
    jest.advanceTimersByTime(30_000);
    expect(verificar).toHaveBeenCalledTimes(2);
  });

  it('expira pedido sem Pix e devolve a vaga uma unica vez', async () => {
    await service.expirarVencidas();
    await service.expirarVencidas();

    expect(solicitacao.status).toBe('EXPIRADA');
    expect(solicitacao.carona.vagas).toBe(1);
    expect(solicitacao.carona.status).toBe('ATIVA');
    expect(salvarCarona).toHaveBeenCalledTimes(1);
    expect(salvarSolicitacao).toHaveBeenCalledTimes(1);
  });

  it('preserva a reserva quando o pagamento ja foi confirmado', async () => {
    pagamentos.push({
      statusProvedor: 'PAID',
      statusCriacao: 'CONFIRMADA',
    } as Pagamento);

    await service.expirarVencidas();

    expect(transaction).not.toHaveBeenCalled();
    expect(solicitacao.status).toBe('ACEITA');
  });

  it('preserva a reserva enquanto o provedor ainda diz PENDING', async () => {
    pagamentos.push({
      idPagamento: 2,
      idProvedor: 'pix_2',
      statusProvedor: 'PENDING',
      statusCriacao: 'CONFIRMADA',
    } as Pagamento);
    consultarPix.mockResolvedValue({ id: 'pix_2', status: 'PENDING' });

    await service.expirarVencidas();

    expect(consultarPix).toHaveBeenCalledWith('pix_2');
    expect(transaction).not.toHaveBeenCalled();
  });

  it('preserva a reserva se a consulta ao provedor falhar', async () => {
    pagamentos.push({
      idPagamento: 2,
      idProvedor: 'pix_2',
      statusProvedor: 'PENDING',
      statusCriacao: 'CONFIRMADA',
    } as Pagamento);
    consultarPix.mockRejectedValue(new Error('Falha de rede'));

    await service.expirarVencidas();

    expect(transaction).not.toHaveBeenCalled();
    expect(solicitacao.status).toBe('ACEITA');
  });

  it('expira e libera vaga quando o provedor confirma Pix expirado', async () => {
    pagamentos.push({
      idPagamento: 2,
      idProvedor: 'pix_2',
      statusProvedor: 'PENDING',
      statusCriacao: 'CONFIRMADA',
    } as Pagamento);
    consultarPix.mockResolvedValue({
      id: 'pix_2',
      status: 'EXPIRED',
      expiraEm: '2026-09-15T11:59:00.000Z',
    });

    await service.expirarVencidas();

    expect(pagamentos[0].statusProvedor).toBe('EXPIRED');
    expect(salvarPagamento).toHaveBeenCalledTimes(1);
    expect(solicitacao.status).toBe('EXPIRADA');
    expect(solicitacao.carona.vagas).toBe(1);
  });

  it('nao libera vaga quando a criacao do Pix e incerta', async () => {
    pagamentos.push({
      statusCriacao: 'INCERTA',
      statusProvedor: null,
    } as Pagamento);

    await service.expirarVencidas();

    expect(transaction).not.toHaveBeenCalled();
  });

  it('nao libera vaga se o pagamento foi confirmado durante a verificacao', async () => {
    const pagamento = {
      idPagamento: 2,
      idProvedor: 'pix_2',
      statusProvedor: 'PENDING',
      statusCriacao: 'CONFIRMADA',
    } as Pagamento;
    pagamentos.push(pagamento);
    consultarPix.mockImplementation(() => {
      pagamento.statusProvedor = 'PAID';
      return Promise.resolve({
        id: 'pix_2',
        status: 'EXPIRED',
        expiraEm: '2026-09-15T11:59:00.000Z',
      });
    });

    await service.expirarVencidas();

    expect(solicitacao.status).toBe('ACEITA');
    expect(salvarCarona).not.toHaveBeenCalled();
  });
});
