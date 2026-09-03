import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  HttpException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { STATUS_PIX } from './abacatepay.types';
import type {
  CobrancaPix,
  ConsultaPix,
  DadosCriacaoPix,
  StatusPix,
} from './abacatepay.types';

@Injectable()
export class AbacatePayService {
  private readonly apiUrl = 'https://api.abacatepay.com/v2';

  constructor(private readonly configService: ConfigService) {}

  async criarPix(dados: DadosCriacaoPix): Promise<CobrancaPix> {
    this.validarCriacao(dados);

    const resposta = await this.requisicao(
      new URL(`${this.apiUrl}/transparents/create`),
      'POST',
      {
        method: 'PIX',
        data: {
          amount: dados.valorCentavos,
          externalId: dados.referencia.trim(),
          ...(dados.descricao !== undefined && {
            description: dados.descricao.trim(),
          }),
          ...(dados.expiraEmSegundos !== undefined && {
            expiresIn: dados.expiraEmSegundos,
          }),
        },
      },
    );

    // O modo depende da chave no painel. Esta checagem ocorre apos a requisicao.
    if (resposta.devMode !== true) {
      throw new BadGatewayException(
        'A AbacatePay nao confirmou o sandbox. Interrompa os testes e confira a chave no painel',
      );
    }

    const consulta = this.converterConsulta(resposta);
    if (
      resposta.amount !== dados.valorCentavos ||
      !this.textoPreenchido(resposta.brCode) ||
      !this.textoPreenchido(resposta.brCodeBase64)
    ) {
      throw new BadGatewayException('Dados da cobranca Pix invalidos');
    }

    return {
      ...consulta,
      valorCentavos: dados.valorCentavos,
      pixCopiaECola: resposta.brCode,
      qrCodeBase64: resposta.brCodeBase64,
      modoTeste: true,
    };
  }

  async consultarPix(id: string): Promise<ConsultaPix> {
    if (!this.textoPreenchido(id)) {
      throw new BadRequestException('Informe o identificador da cobranca Pix');
    }

    const url = new URL(`${this.apiUrl}/transparents/check`);
    url.searchParams.set('id', id.trim());
    const dados = await this.requisicao(url, 'GET');
    const consulta = this.converterConsulta(dados);

    if (consulta.id !== id.trim()) {
      throw new BadGatewayException('A AbacatePay retornou outra cobranca Pix');
    }

    return consulta;
  }

  private async requisicao(
    url: URL,
    metodo: 'GET' | 'POST',
    corpo?: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const chave = this.obterChave();
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const resposta = await fetch(url, {
        method: metodo,
        headers: {
          Authorization: `Bearer ${chave}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        ...(corpo !== undefined && { body: JSON.stringify(corpo) }),
        signal: controller.signal,
        redirect: 'error',
      });

      if (resposta.status === 401 || resposta.status === 403) {
        throw new ServiceUnavailableException(
          'Confira a chave de testes e as permissoes da AbacatePay no backend',
        );
      }

      if (!resposta.ok) {
        throw new BadGatewayException('A AbacatePay recusou a operacao Pix');
      }

      const resultado: unknown = await resposta.json();
      if (
        !this.objeto(resultado) ||
        resultado.error != null ||
        !this.sucesso(resultado.success) ||
        !this.objeto(resultado.data)
      ) {
        throw new BadGatewayException('Resposta invalida da AbacatePay');
      }

      return resultado.data;
    } catch (erro) {
      if (erro instanceof HttpException) {
        throw erro;
      }

      if (controller.signal.aborted) {
        throw new GatewayTimeoutException(
          'A AbacatePay demorou para responder. Confira a cobranca antes de tentar novamente',
        );
      }

      // Sem repeticao automatica: um POST pode ter criado a cobranca antes da falha.
      throw new BadGatewayException(
        'Nao foi possivel confirmar a operacao Pix. Confira a cobranca antes de tentar novamente',
      );
    } finally {
      clearTimeout(timeout);
    }
  }

  private obterChave(): string {
    const chave = this.configService.get<string>('ABACATEPAY_API_KEY')?.trim();
    if (!chave) {
      throw new ServiceUnavailableException(
        'AbacatePay nao configurada no backend',
      );
    }

    if (
      this.configService.get<string>('NODE_ENV') === 'production' ||
      chave.startsWith('prod_')
    ) {
      throw new ServiceUnavailableException(
        'A integracao de pagamentos ainda esta disponivel apenas para testes',
      );
    }

    return chave;
  }

  private validarCriacao(dados: DadosCriacaoPix): void {
    if (
      !Number.isSafeInteger(dados.valorCentavos) ||
      dados.valorCentavos <= 0
    ) {
      throw new BadRequestException(
        'O valor do Pix deve ser um inteiro positivo em centavos',
      );
    }

    if (!this.textoPreenchido(dados.referencia)) {
      throw new BadRequestException('Informe a referencia da cobranca Pix');
    }

    if (
      dados.descricao !== undefined &&
      (!this.textoPreenchido(dados.descricao) ||
        dados.descricao.trim().length > 500)
    ) {
      throw new BadRequestException(
        'A descricao do Pix deve ter de 1 a 500 caracteres',
      );
    }

    if (
      dados.expiraEmSegundos !== undefined &&
      (!Number.isSafeInteger(dados.expiraEmSegundos) ||
        dados.expiraEmSegundos <= 0)
    ) {
      throw new BadRequestException(
        'A expiracao do Pix deve ser um inteiro positivo em segundos',
      );
    }
  }

  private converterConsulta(dados: Record<string, unknown>): ConsultaPix {
    if (
      !this.textoPreenchido(dados.id) ||
      !this.statusValido(dados.status) ||
      !this.textoPreenchido(dados.expiresAt) ||
      !Number.isFinite(Date.parse(dados.expiresAt))
    ) {
      throw new BadGatewayException('Dados da cobranca Pix invalidos');
    }

    return {
      id: dados.id,
      status: dados.status,
      expiraEm: dados.expiresAt,
    };
  }

  private statusValido(valor: unknown): valor is StatusPix {
    return STATUS_PIX.some((status) => status === valor);
  }

  private objeto(valor: unknown): valor is Record<string, unknown> {
    return typeof valor === 'object' && valor !== null && !Array.isArray(valor);
  }

  private textoPreenchido(valor: unknown): valor is string {
    return typeof valor === 'string' && valor.trim().length > 0;
  }

  private sucesso(valor: unknown): boolean {
    // Os exemplos oficiais da v2 usam tanto true quanto { message: ... }.
    return (
      valor === true ||
      (this.objeto(valor) && this.textoPreenchido(valor.message))
    );
  }
}
