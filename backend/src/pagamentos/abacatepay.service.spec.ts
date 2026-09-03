import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';

import { AbacatePayService } from './abacatepay.service';
import { STATUS_PIX } from './abacatepay.types';
import { PagamentosModule } from './pagamentos.module';

describe('AbacatePayService', () => {
  let service: AbacatePayService;
  let fetchMock: jest.SpiedFunction<typeof fetch>;
  let configuracao: Record<string, string | undefined>;
  let configService: ConfigService;

  const entrada = {
    valorCentavos: 1250,
    referencia: 'pagamento-teste-1',
  };
  const cobranca = {
    id: 'pix_char_teste',
    amount: 1250,
    status: 'PENDING',
    devMode: true,
    brCode: 'codigo-pix-ficticio',
    brCodeBase64: 'data:image/png;base64,aW1hZ2VtLXRlc3Rl',
    expiresAt: '2026-09-03T18:00:00.000Z',
  };

  function resposta(data: unknown = cobranca, success: unknown = true) {
    return new Response(JSON.stringify({ data, success, error: null }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  beforeEach(() => {
    configuracao = {
      ABACATEPAY_API_KEY: 'dev_chave-ficticia',
      NODE_ENV: 'test',
    };
    configService = {
      get: jest.fn((chave: string) => configuracao[chave]),
    } as unknown as ConfigService;
    service = new AbacatePayService(configService);

    // Nenhum teste pode acessar a rede, nem quando esquecer de configurar a resposta.
    fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockRejectedValue(new Error('Rede simulada'));
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.restoreAllMocks();
  });

  it('carrega o modulo sem chave, sem ler o .env e sem fazer requisicoes', async () => {
    delete configuracao.ABACATEPAY_API_KEY;
    const modulo = await Test.createTestingModule({
      imports: [PagamentosModule],
    })
      .overrideProvider(ConfigService)
      .useValue(configService)
      .compile();

    try {
      expect(modulo.get(AbacatePayService)).toBeInstanceOf(AbacatePayService);
      expect(fetchMock).not.toHaveBeenCalled();
    } finally {
      await modulo.close();
    }
  });

  it('cria Pix pelo contrato v2, com centavos e sem dados extras do provedor', async () => {
    fetchMock.mockResolvedValue(
      resposta({ ...cobranca, campoExtra: 'ignorado' }),
    );

    await expect(service.criarPix(entrada)).resolves.toEqual({
      id: 'pix_char_teste',
      valorCentavos: 1250,
      status: 'PENDING',
      pixCopiaECola: cobranca.brCode,
      qrCodeBase64: cobranca.brCodeBase64,
      expiraEm: cobranca.expiresAt,
      modoTeste: true,
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, opcoes] = fetchMock.mock.calls[0];
    expect(url).toBeInstanceOf(URL);
    expect((url as URL).href).toBe(
      'https://api.abacatepay.com/v2/transparents/create',
    );
    expect(opcoes).toMatchObject({
      method: 'POST',
      headers: {
        Authorization: 'Bearer dev_chave-ficticia',
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        method: 'PIX',
        data: { amount: 1250, externalId: entrada.referencia },
      }),
      redirect: 'error',
    });
    expect(opcoes?.signal).toBeInstanceOf(AbortSignal);
  });

  it('envia descricao e expiracao somente quando informadas', async () => {
    fetchMock.mockResolvedValue(resposta());

    await service.criarPix({
      ...entrada,
      referencia: ' pagamento-teste-1 ',
      descricao: ' Carona de teste ',
      expiraEmSegundos: 900,
    });

    expect(fetchMock.mock.calls[0][1]?.body).toBe(
      JSON.stringify({
        method: 'PIX',
        data: {
          amount: 1250,
          externalId: 'pagamento-teste-1',
          description: 'Carona de teste',
          expiresIn: 900,
        },
      }),
    );
  });

  it('aceita o formato alternativo de sucesso dos exemplos oficiais', async () => {
    fetchMock.mockResolvedValue(resposta(cobranca, { message: 'Criada' }));
    await expect(service.criarPix(entrada)).resolves.toMatchObject({
      modoTeste: true,
    });
  });

  it.each([0, -1, 12.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1])(
    'recusa valor invalido %s antes de enviar a API',
    async (valorCentavos) => {
      await expect(
        service.criarPix({ ...entrada, valorCentavos }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(fetchMock).not.toHaveBeenCalled();
    },
  );

  it('exige referencia para identificar a cobranca', async () => {
    await expect(
      service.criarPix({ ...entrada, referencia: '  ' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([' ', 'a'.repeat(501)])(
    'recusa descricao vazia ou longa demais',
    async (descricao) => {
      await expect(
        service.criarPix({ ...entrada, descricao }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(fetchMock).not.toHaveBeenCalled();
    },
  );

  it.each([0, -1, 1.5, NaN, Infinity])(
    'recusa expiracao invalida %s',
    async (expiraEmSegundos) => {
      await expect(
        service.criarPix({ ...entrada, expiraEmSegundos }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(fetchMock).not.toHaveBeenCalled();
    },
  );

  it.each([undefined, '', '  '])(
    'recusa chave ausente ou vazia',
    async (chave) => {
      configuracao.ABACATEPAY_API_KEY = chave;
      await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
      expect(fetchMock).not.toHaveBeenCalled();
    },
  );

  it('bloqueia a integracao quando NODE_ENV e production', async () => {
    configuracao.NODE_ENV = 'production';
    await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('recusa chaves com prefixo explicitamente de producao', async () => {
    configuracao.ABACATEPAY_API_KEY = 'prod_chave-ficticia';
    await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it.each([false, undefined, 'true'])(
    'nao aceita criacao sem devMode booleano true',
    async (devMode) => {
      fetchMock.mockResolvedValue(resposta({ ...cobranca, devMode }));
      await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
        BadGatewayException,
      );
    },
  );

  it.each([
    { amount: 1 },
    { amount: '1250' },
    { id: '' },
    { status: 'DESCONHECIDO' },
    { expiresAt: 'data-invalida' },
    { brCode: '' },
    { brCodeBase64: null },
  ])('recusa campos invalidos na cobranca: %j', async (campos) => {
    fetchMock.mockResolvedValue(resposta({ ...cobranca, ...campos }));
    await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it.each([
    null,
    [],
    { success: false, data: cobranca },
    { success: true, data: null },
    { success: true, data: cobranca, error: 'falha' },
    { data: cobranca },
  ])('recusa envelope de resposta invalido', async (corpo) => {
    fetchMock.mockResolvedValue(
      new Response(JSON.stringify(corpo), { status: 200 }),
    );
    await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it.each([401, 403])(
    'orienta conferir credenciais e permissoes no HTTP %s',
    async (status) => {
      fetchMock.mockResolvedValue(
        new Response('segredo do provedor', { status }),
      );
      await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
        ServiceUnavailableException,
      );
      expect(fetchMock).toHaveBeenCalledTimes(1);
    },
  );

  it.each([400, 404, 429, 500, 502])(
    'trata HTTP %s sem expor resposta nem repetir o pedido',
    async (status) => {
      fetchMock.mockResolvedValue(
        new Response('segredo do provedor', { status }),
      );
      await expect(service.criarPix(entrada)).rejects.toThrow(
        'A AbacatePay recusou a operacao Pix',
      );
      expect(fetchMock).toHaveBeenCalledTimes(1);
    },
  );

  it('trata JSON invalido sem repetir a criacao', async () => {
    fetchMock.mockResolvedValue(
      new Response('<html>erro</html>', { status: 200 }),
    );
    await expect(service.criarPix(entrada)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('nao expoe a chave nem repete automaticamente uma falha de rede', async () => {
    fetchMock.mockRejectedValue(new Error('falha com dev_chave-ficticia'));
    await expect(service.criarPix(entrada)).rejects.toThrow(
      'Nao foi possivel confirmar a operacao Pix. Confira a cobranca antes de tentar novamente',
    );
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('aborta apos dez segundos e limpa o temporizador', async () => {
    jest.useFakeTimers();
    fetchMock.mockImplementation(
      (_url, opcoes) =>
        new Promise<Response>((_resolve, reject) => {
          opcoes?.signal?.addEventListener(
            'abort',
            () => reject(new Error('Abortado')),
            { once: true },
          );
        }),
    );

    const resultado = service.criarPix(entrada);
    const verificacao = expect(resultado).rejects.toBeInstanceOf(
      GatewayTimeoutException,
    );
    await jest.advanceTimersByTimeAsync(10_000);
    await verificacao;

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][1]?.signal?.aborted).toBe(true);
    expect(jest.getTimerCount()).toBe(0);
  });

  it('limpa o temporizador quando a requisicao termina normalmente', async () => {
    jest.useFakeTimers();
    fetchMock.mockResolvedValue(resposta());
    await service.criarPix(entrada);
    expect(jest.getTimerCount()).toBe(0);
  });

  it.each(STATUS_PIX)(
    'consulta status %s sem confundir os estados do pagamento',
    async (status) => {
      fetchMock.mockResolvedValue(
        resposta({
          id: cobranca.id,
          status,
          expiresAt: cobranca.expiresAt,
        }),
      );

      await expect(service.consultarPix(cobranca.id)).resolves.toEqual({
        id: cobranca.id,
        status,
        expiraEm: cobranca.expiresAt,
      });
      expect((fetchMock.mock.calls[0][0] as URL).href).toBe(
        'https://api.abacatepay.com/v2/transparents/check?id=pix_char_teste',
      );
      expect(fetchMock.mock.calls[0][1]?.method).toBe('GET');
      expect(fetchMock.mock.calls[0][1]?.body).toBeUndefined();
    },
  );

  it('mantem caracteres especiais do id dentro de um unico parametro', async () => {
    const id = 'pix_teste&outro=1';
    fetchMock.mockResolvedValue(resposta({ ...cobranca, id }));
    await service.consultarPix(id);
    const url = fetchMock.mock.calls[0][0] as URL;
    expect([...url.searchParams.entries()]).toEqual([['id', id]]);
  });

  it('recusa consulta sem identificador', async () => {
    await expect(service.consultarPix('  ')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('recusa uma consulta que retorna outra cobranca', async () => {
    fetchMock.mockResolvedValue(resposta({ ...cobranca, id: 'pix_outro' }));
    await expect(service.consultarPix(cobranca.id)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });
});
