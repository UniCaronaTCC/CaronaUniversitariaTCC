import {
  BadRequestException,
  ConflictException,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { DataSource, Repository } from 'typeorm';

import {
  ABACATEPAY_PUBLIC_HMAC_KEY,
  AbacatePayWebhookService,
} from './abacatepay-webhook.service';
import { AbacatePayService } from './abacatepay.service';
import { PagamentoEventoWebhook } from './pagamento-evento-webhook.entity';
import { Pagamento } from './pagamento.entity';

describe('AbacatePayWebhookService', () => {
  const secret = 'secret-de-webhook-com-mais-de-32-caracteres';
  const corpoValido = {
    id: 'log_123',
    event: 'transparent.completed',
    apiVersion: 2,
    devMode: true,
    data: {
      transparent: {
        id: 'pix_123',
        externalId: 'd7d1c644-9383-4a70-94f7-c6292f0065a5',
        amount: 500,
        paidAmount: 500,
        status: 'PAID',
        frequency: 'ONE_TIME',
        devMode: true,
        methods: ['PIX'],
      },
    },
  };

  let service: AbacatePayWebhookService;
  let configuracao: Record<string, string | undefined>;
  let pagamentosRepository: { findOne: jest.Mock };
  let eventosRepository: { findOneBy: jest.Mock };
  let abacatePayService: { consultarPix: jest.Mock };
  let pagamentosTransacaoRepository: {
    createQueryBuilder: jest.Mock;
    save: jest.Mock;
  };
  let eventosTransacaoRepository: {
    findOneBy: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let consultaPagamento: {
    where: jest.Mock;
    setLock: jest.Mock;
    getOne: jest.Mock;
  };
  let pagamento: Pagamento;

  beforeEach(() => {
    configuracao = { ABACATEPAY_WEBHOOK_SECRET: secret };
    pagamento = {
      idPagamento: 30,
      statusCriacao: 'CONFIRMADA',
      statusProvedor: 'PENDING',
    } as Pagamento;
    pagamentosRepository = {
      findOne: jest.fn().mockResolvedValue(pagamento),
    };
    eventosRepository = {
      findOneBy: jest.fn().mockResolvedValue(null),
    };
    abacatePayService = {
      consultarPix: jest.fn().mockResolvedValue({
        id: 'pix_123',
        status: 'PAID',
        expiraEm: '2026-09-04T12:00:00.000Z',
      }),
    };
    consultaPagamento = {
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: jest.fn().mockResolvedValue(pagamento),
    };
    pagamentosTransacaoRepository = {
      createQueryBuilder: jest.fn().mockReturnValue(consultaPagamento),
      save: jest.fn((item: Pagamento) => Promise.resolve(item)),
    };
    eventosTransacaoRepository = {
      findOneBy: jest.fn().mockResolvedValue(null),
      create: jest.fn(
        (item: Partial<PagamentoEventoWebhook>) =>
          item as PagamentoEventoWebhook,
      ),
      save: jest.fn((item: PagamentoEventoWebhook) => Promise.resolve(item)),
    };
    const dataSource = {
      transaction: jest.fn((executar: (manager: unknown) => Promise<unknown>) =>
        executar({
          getRepository: (entidade: unknown) =>
            entidade === Pagamento
              ? pagamentosTransacaoRepository
              : eventosTransacaoRepository,
        }),
      ),
    };
    const configService = {
      get: jest.fn((chave: string) => configuracao[chave]),
    } as unknown as ConfigService;

    service = new AbacatePayWebhookService(
      configService,
      pagamentosRepository as unknown as Repository<Pagamento>,
      eventosRepository as unknown as Repository<PagamentoEventoWebhook>,
      dataSource as unknown as DataSource,
      abacatePayService as unknown as AbacatePayService,
    );
  });

  it('confirma o Pix e registra o evento uma unica vez', async () => {
    const resultado = await processar(corpoValido);

    expect(resultado).toEqual({ processado: true, duplicado: false });
    expect(abacatePayService.consultarPix).toHaveBeenCalledWith('pix_123');
    expect(consultaPagamento.setLock).toHaveBeenCalledWith('pessimistic_write');
    expect(pagamento.statusProvedor).toBe('PAID');
    expect(pagamentosTransacaoRepository.save).toHaveBeenCalledWith(pagamento);
    expect(eventosTransacaoRepository.create).toHaveBeenCalledWith({
      idEvento: 'log_123',
      pagamento,
      tipo: 'transparent.completed',
    });
    expect(eventosTransacaoRepository.save).toHaveBeenCalledTimes(1);
  });

  it('aceita novamente um evento ja processado sem repetir operacoes', async () => {
    eventosRepository.findOneBy.mockResolvedValue({ idEvento: 'log_123' });

    await expect(processar(corpoValido)).resolves.toEqual({
      processado: true,
      duplicado: true,
    });
    expect(pagamentosRepository.findOne).not.toHaveBeenCalled();
    expect(abacatePayService.consultarPix).not.toHaveBeenCalled();
  });

  it.each([
    { secretRecebido: 'secret-incorreto', assinaturaRecebida: undefined },
    { secretRecebido: secret, assinaturaRecebida: 'assinatura-invalida' },
  ])('recusa secret ou assinatura invalidos', async (dadosInvalidos) => {
    const corpoBruto = Buffer.from(JSON.stringify(corpoValido));

    await expect(
      service.processar({
        ...dadosInvalidos,
        corpoBruto,
        corpo: corpoValido,
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(eventosRepository.findOneBy).not.toHaveBeenCalled();
  });

  it('recusa quando o secret nao foi configurado', async () => {
    delete configuracao.ABACATEPAY_WEBHOOK_SECRET;

    await expect(processar(corpoValido)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(eventosRepository.findOneBy).not.toHaveBeenCalled();
  });

  it('recusa valor pago diferente do valor da cobranca', async () => {
    const corpo = {
      ...corpoValido,
      data: {
        transparent: {
          ...corpoValido.data.transparent,
          paidAmount: 400,
        },
      },
    };

    await expect(processar(corpo)).rejects.toBeInstanceOf(BadRequestException);
    expect(pagamentosRepository.findOne).not.toHaveBeenCalled();
  });

  it('nao processa evento valido de outro tipo', async () => {
    const corpo = { ...corpoValido, event: 'transparent.refunded' };

    await expect(processar(corpo)).resolves.toEqual({
      processado: false,
      duplicado: false,
    });
    expect(pagamentosRepository.findOne).not.toHaveBeenCalled();
  });

  it('recusa webhook que nao corresponde ao pagamento salvo', async () => {
    pagamentosRepository.findOne.mockResolvedValue(null);

    await expect(processar(corpoValido)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(abacatePayService.consultarPix).not.toHaveBeenCalled();
  });

  it('aguarda a confirmacao da propria API antes de marcar como pago', async () => {
    abacatePayService.consultarPix.mockResolvedValue({
      id: 'pix_123',
      status: 'PENDING',
      expiraEm: '2026-09-04T12:00:00.000Z',
    });

    await expect(processar(corpoValido)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(pagamentosTransacaoRepository.save).not.toHaveBeenCalled();
  });

  it('trata como duplicado quando duas entregas chegam juntas', async () => {
    eventosTransacaoRepository.findOneBy.mockResolvedValue({
      idEvento: 'log_123',
    });

    await expect(processar(corpoValido)).resolves.toEqual({
      processado: true,
      duplicado: true,
    });
    expect(pagamentosTransacaoRepository.save).not.toHaveBeenCalled();
    expect(eventosTransacaoRepository.save).not.toHaveBeenCalled();
  });

  function processar(corpo: Record<string, unknown>) {
    const corpoBruto = Buffer.from(JSON.stringify(corpo));
    const assinatura = createHmac('sha256', ABACATEPAY_PUBLIC_HMAC_KEY)
      .update(corpoBruto)
      .digest('base64');

    return service.processar({
      secretRecebido: secret,
      assinaturaRecebida: assinatura,
      corpoBruto,
      corpo,
    });
  }
});
