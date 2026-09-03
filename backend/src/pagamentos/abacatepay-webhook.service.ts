import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { DataSource, Repository } from 'typeorm';

import { AbacatePayService } from './abacatepay.service';
import { PagamentoEventoWebhook } from './pagamento-evento-webhook.entity';
import { Pagamento } from './pagamento.entity';

export const ABACATEPAY_PUBLIC_HMAC_KEY =
  't9dXRhHHo3yDEj5pVDYz0frf7q6bMKyMRmxxCPIPp3RCplBfXRxqlC6ZpiWmOqj4L63qEaeUOtrCI8P0VMUgo6iIga2ri9ogaHFs0WIIywSMg0q7RmBfybe1E5XJcfC4IW3alNqym0tXoAKkzvfEjZxV6bE0oG2zJrNNYmUCKZyV0KZ3JS8Votf9EAWWYdiDkMkpbMdPggfh1EqHlVkMiTady6jOR3hyzGEHrIz2Ret0xHKMbiqkr9HS1JhNHDX9';

interface DadosWebhookRecebidos {
  secretRecebido: string | undefined;
  assinaturaRecebida: string | undefined;
  corpoBruto: Buffer;
  corpo: unknown;
}

interface EventoPagamentoConcluido {
  idEvento: string;
  tipo: 'transparent.completed';
  idProvedor: string;
  referencia: string;
  valorCentavos: number;
}

export interface ResultadoWebhook {
  processado: boolean;
  duplicado: boolean;
}

@Injectable()
export class AbacatePayWebhookService {
  constructor(
    private readonly configService: ConfigService,
    @InjectRepository(Pagamento)
    private readonly pagamentosRepository: Repository<Pagamento>,
    @InjectRepository(PagamentoEventoWebhook)
    private readonly eventosRepository: Repository<PagamentoEventoWebhook>,
    private readonly dataSource: DataSource,
    private readonly abacatePayService: AbacatePayService,
  ) {}

  async processar(dados: DadosWebhookRecebidos): Promise<ResultadoWebhook> {
    this.validarAutenticidade(dados);
    const evento = this.extrairEvento(dados.corpo);

    if (evento === null) {
      return { processado: false, duplicado: false };
    }

    const eventoExistente = await this.eventosRepository.findOneBy({
      idEvento: evento.idEvento,
    });
    if (eventoExistente) {
      return { processado: true, duplicado: true };
    }

    const pagamento = await this.pagamentosRepository.findOne({
      where: {
        idProvedor: evento.idProvedor,
        referencia: evento.referencia,
        valorCentavos: evento.valorCentavos,
        provedor: 'ABACATEPAY',
        metodo: 'PIX',
        modoTeste: true,
      },
    });

    if (!pagamento) {
      throw new NotFoundException('Pagamento do webhook nao encontrado');
    }

    const consulta = await this.abacatePayService.consultarPix(
      evento.idProvedor,
    );
    if (consulta.status !== 'PAID') {
      throw new ConflictException(
        'A AbacatePay ainda nao confirmou o pagamento',
      );
    }

    return this.registrarEvento(evento, pagamento.idPagamento);
  }

  private validarAutenticidade(dados: DadosWebhookRecebidos): void {
    const secretEsperado = this.configService
      .get<string>('ABACATEPAY_WEBHOOK_SECRET')
      ?.trim();

    if (!secretEsperado || secretEsperado.length < 32) {
      throw new ServiceUnavailableException(
        'Webhook da AbacatePay nao configurado no backend',
      );
    }

    if (
      !dados.secretRecebido ||
      !this.compararSeguro(dados.secretRecebido, secretEsperado)
    ) {
      throw new UnauthorizedException('Webhook nao autorizado');
    }

    if (!dados.assinaturaRecebida) {
      throw new UnauthorizedException('Assinatura do webhook ausente');
    }

    const assinaturaEsperada = createHmac('sha256', ABACATEPAY_PUBLIC_HMAC_KEY)
      .update(dados.corpoBruto)
      .digest('base64');

    if (!this.compararSeguro(dados.assinaturaRecebida, assinaturaEsperada)) {
      throw new UnauthorizedException('Assinatura do webhook invalida');
    }
  }

  private extrairEvento(corpo: unknown): EventoPagamentoConcluido | null {
    if (!this.objeto(corpo) || !this.textoValido(corpo.event, 50)) {
      throw new BadRequestException('Evento de webhook invalido');
    }

    if (corpo.event !== 'transparent.completed') {
      return null;
    }

    const dados = corpo.data;
    const transparente = this.objeto(dados) ? dados.transparent : null;

    if (
      !this.textoValido(corpo.id, 100) ||
      corpo.apiVersion !== 2 ||
      !this.objeto(transparente) ||
      !this.textoValido(transparente.id, 100) ||
      !this.textoValido(transparente.externalId, 100) ||
      transparente.status !== 'PAID' ||
      transparente.devMode !== true ||
      transparente.frequency !== 'ONE_TIME' ||
      !Array.isArray(transparente.methods) ||
      !transparente.methods.includes('PIX') ||
      !this.inteiroSeguro(transparente.amount) ||
      !this.inteiroSeguro(transparente.paidAmount) ||
      transparente.amount <= 0 ||
      transparente.paidAmount !== transparente.amount
    ) {
      throw new BadRequestException('Dados do pagamento no webhook invalidos');
    }

    return {
      idEvento: corpo.id,
      tipo: 'transparent.completed',
      idProvedor: transparente.id,
      referencia: transparente.externalId,
      valorCentavos: transparente.amount,
    };
  }

  private async registrarEvento(
    evento: EventoPagamentoConcluido,
    idPagamento: number,
  ): Promise<ResultadoWebhook> {
    return this.dataSource.transaction(async (manager) => {
      const pagamentosRepository = manager.getRepository(Pagamento);
      const eventosRepository = manager.getRepository(PagamentoEventoWebhook);

      const pagamento = await pagamentosRepository
        .createQueryBuilder('pagamento')
        .where('pagamento.idPagamento = :idPagamento', { idPagamento })
        .setLock('pessimistic_write')
        .getOne();

      if (!pagamento) {
        throw new NotFoundException('Pagamento do webhook nao encontrado');
      }

      const eventoExistente = await eventosRepository.findOneBy({
        idEvento: evento.idEvento,
      });
      if (eventoExistente) {
        return { processado: true, duplicado: true };
      }

      pagamento.statusCriacao = 'CONFIRMADA';
      pagamento.statusProvedor = 'PAID';
      await pagamentosRepository.save(pagamento);

      const novoEvento = eventosRepository.create({
        idEvento: evento.idEvento,
        pagamento,
        tipo: evento.tipo,
      });
      await eventosRepository.save(novoEvento);

      return { processado: true, duplicado: false };
    });
  }

  private compararSeguro(valorA: string, valorB: string): boolean {
    const bufferA = Buffer.from(valorA, 'utf8');
    const bufferB = Buffer.from(valorB, 'utf8');

    return (
      bufferA.length === bufferB.length && timingSafeEqual(bufferA, bufferB)
    );
  }

  private objeto(valor: unknown): valor is Record<string, unknown> {
    return typeof valor === 'object' && valor !== null && !Array.isArray(valor);
  }

  private textoValido(valor: unknown, tamanhoMaximo: number): valor is string {
    return (
      typeof valor === 'string' &&
      valor.trim().length > 0 &&
      valor.length <= tamanhoMaximo
    );
  }

  private inteiroSeguro(valor: unknown): valor is number {
    return typeof valor === 'number' && Number.isSafeInteger(valor);
  }
}
