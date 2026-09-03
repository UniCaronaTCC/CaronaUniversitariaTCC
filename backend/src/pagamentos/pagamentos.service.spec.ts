import {
  ConflictException,
  GatewayTimeoutException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { AbacatePayService } from './abacatepay.service';
import { Pagamento } from './pagamento.entity';
import { PagamentosService } from './pagamentos.service';

describe('PagamentosService', () => {
  let service: PagamentosService;
  let pagamentosRepository: {
    save: jest.Mock;
    update: jest.Mock;
  };
  let pagamentosTransacaoRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let abacatePayService: { criarPix: jest.Mock };
  let dataSource: { transaction: jest.Mock };
  let consultaSolicitacao: {
    innerJoinAndSelect: jest.Mock;
    where: jest.Mock;
    setLock: jest.Mock;
    getOne: jest.Mock;
  };

  const solicitacaoAceita = {
    idSolicitacao: 10,
    status: 'ACEITA',
    passageiro: { idUsuario: 1 },
    carona: {
      idCarona: 20,
      recorrente: false,
      valor: 12.5,
    },
  } as Solicitacao;

  beforeEach(() => {
    consultaSolicitacao = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(solicitacaoAceita),
    };

    pagamentosRepository = {
      save: jest.fn((pagamento: Pagamento) => Promise.resolve(pagamento)),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    pagamentosTransacaoRepository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((dados: Partial<Pagamento>) => dados as Pagamento),
      save: jest.fn((pagamento: Pagamento) =>
        Promise.resolve({
          ...pagamento,
          idPagamento: 30,
          criadoEm: new Date('2026-09-03T12:00:00.000Z'),
        }),
      ),
    };
    abacatePayService = {
      criarPix: jest.fn().mockResolvedValue({
        id: 'pix_123',
        status: 'PENDING',
        expiraEm: '2026-09-04T12:00:00.000Z',
        valorCentavos: 1250,
        pixCopiaECola: 'codigo-pix',
        qrCodeBase64: 'qr-base64',
        modoTeste: true,
      }),
    };
    dataSource = {
      transaction: jest.fn((executar: (manager: unknown) => Promise<unknown>) =>
        executar({
          getRepository: (entidade: unknown) =>
            entidade === Solicitacao
              ? { createQueryBuilder: () => consultaSolicitacao }
              : pagamentosTransacaoRepository,
        }),
      ),
    };

    service = new PagamentosService(
      pagamentosRepository as unknown as Repository<Pagamento>,
      dataSource as unknown as DataSource,
      abacatePayService as unknown as AbacatePayService,
    );
  });

  it('calcula o valor no servidor, cria o Pix e salva sua confirmacao', async () => {
    const resultado = await service.criarOuObterPix(10, 1);

    expect(consultaSolicitacao.setLock).toHaveBeenCalledWith(
      'pessimistic_write',
      undefined,
      ['solicitacao'],
    );
    expect(pagamentosTransacaoRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        solicitacao: solicitacaoAceita,
        valorCentavos: 1250,
        statusCriacao: 'PREPARADA',
      }),
    );
    expect(abacatePayService.criarPix).toHaveBeenCalledWith(
      expect.objectContaining({
        valorCentavos: 1250,
        descricao: 'Carona 20 - solicitacao 10',
      }),
    );
    expect(resultado).toEqual(
      expect.objectContaining({
        statusCriacao: 'CONFIRMADA',
        idProvedor: 'pix_123',
        statusProvedor: 'PENDING',
        pixCopiaECola: 'codigo-pix',
        qrCodeBase64: 'qr-base64',
        modoTeste: true,
      }),
    );
  });

  it('reutiliza uma tentativa existente sem chamar a AbacatePay', async () => {
    const existente = {
      idPagamento: 8,
      statusCriacao: 'PREPARADA',
      solicitacao: solicitacaoAceita,
    } as Pagamento;
    pagamentosTransacaoRepository.findOne.mockResolvedValue(existente);

    await expect(service.criarOuObterPix(10, 1)).resolves.toBe(existente);
    expect(pagamentosTransacaoRepository.findOne).toHaveBeenCalledWith(
      expect.objectContaining({ relations: { solicitacao: true } }),
    );
    expect(pagamentosTransacaoRepository.create).not.toHaveBeenCalled();
    expect(abacatePayService.criarPix).not.toHaveBeenCalled();
  });

  it.each([
    { solicitacao: null, idPassageiro: 1 },
    {
      solicitacao: {
        ...solicitacaoAceita,
        passageiro: { idUsuario: 2 },
      },
      idPassageiro: 1,
    },
  ])('nao revela solicitacao ausente ou de outro passageiro', async (caso) => {
    consultaSolicitacao.getOne.mockResolvedValue(caso.solicitacao);

    await expect(
      service.criarOuObterPix(10, caso.idPassageiro),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(abacatePayService.criarPix).not.toHaveBeenCalled();
  });

  it('recusa solicitacao que ainda nao foi aceita', async () => {
    consultaSolicitacao.getOne.mockResolvedValue({
      ...solicitacaoAceita,
      status: 'PENDENTE',
    });

    await expect(service.criarOuObterPix(10, 1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(abacatePayService.criarPix).not.toHaveBeenCalled();
  });

  it('recusa carona recorrente nesta primeira versao', async () => {
    consultaSolicitacao.getOne.mockResolvedValue({
      ...solicitacaoAceita,
      carona: { ...solicitacaoAceita.carona, recorrente: true },
    });

    await expect(service.criarOuObterPix(10, 1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(abacatePayService.criarPix).not.toHaveBeenCalled();
  });

  it('marca como INCERTA quando nao sabe se a API criou a cobranca', async () => {
    abacatePayService.criarPix.mockRejectedValue(
      new GatewayTimeoutException('tempo esgotado'),
    );

    await expect(service.criarOuObterPix(10, 1)).rejects.toBeInstanceOf(
      GatewayTimeoutException,
    );
    expect(pagamentosRepository.update).toHaveBeenCalledWith(30, {
      statusCriacao: 'INCERTA',
    });
  });

  it('marca como FALHOU quando a integracao nem esta disponivel', async () => {
    abacatePayService.criarPix.mockRejectedValue(
      new ServiceUnavailableException('sem chave'),
    );

    await expect(service.criarOuObterPix(10, 1)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(pagamentosRepository.update).toHaveBeenCalledWith(30, {
      statusCriacao: 'FALHOU',
    });
  });

  it('bloqueia nova tentativa se a API respondeu e a confirmacao nao foi salva', async () => {
    pagamentosRepository.save.mockRejectedValue(
      new Error('banco indisponivel'),
    );

    await expect(service.criarOuObterPix(10, 1)).rejects.toThrow(
      'A cobranca foi criada, mas nao foi possivel salvar sua confirmacao',
    );
    expect(pagamentosRepository.update).toHaveBeenCalledWith(30, {
      statusCriacao: 'INCERTA',
    });
  });

  it('recusa valor gratuito ou invalido antes de chamar o provedor', async () => {
    consultaSolicitacao.getOne.mockResolvedValue({
      ...solicitacaoAceita,
      carona: { ...solicitacaoAceita.carona, valor: 0 },
    });

    await expect(service.criarOuObterPix(10, 1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(abacatePayService.criarPix).not.toHaveBeenCalled();
  });
});
