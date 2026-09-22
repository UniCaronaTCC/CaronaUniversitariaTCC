import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { DataSource, In, Repository } from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { AbacatePayService } from './abacatepay.service';
import type { CobrancaPix, StatusPix } from './abacatepay.types';
import { Pagamento, StatusCriacaoPagamento } from './pagamento.entity';
import { calcularDuracaoPixSegundos } from './prazo-pagamento';

const STATUS_QUE_BLOQUEIAM_NOVA_TENTATIVA: StatusCriacaoPagamento[] = [
  'PREPARADA',
  'CONFIRMADA',
  'INCERTA',
];

const STATUS_PIX_QUE_PERMITEM_NOVA_TENTATIVA: ReadonlySet<StatusPix> = new Set([
  'EXPIRED',
  'CANCELLED',
  'FAILED',
]);

type PreparacaoPagamento =
  | { pagamento: Pagamento; criadoAgora: false }
  | {
      pagamento: Pagamento;
      criadoAgora: true;
      expiraEmSegundos: number;
    };

@Injectable()
export class PagamentosService {
  constructor(
    @InjectRepository(Pagamento)
    private readonly pagamentosRepository: Repository<Pagamento>,
    private readonly dataSource: DataSource,
    private readonly abacatePayService: AbacatePayService,
  ) {}

  async obterPagamento(
    idPagamento: number,
    idPassageiro: number,
  ): Promise<Pagamento> {
    const pagamento = await this.pagamentosRepository.findOne({
      where: {
        idPagamento,
        solicitacao: { passageiro: { idUsuario: idPassageiro } },
      },
      relations: { solicitacao: true },
    });

    if (!pagamento) {
      throw new NotFoundException('Pagamento nao encontrado');
    }

    return pagamento;
  }

  async criarOuObterPix(
    idSolicitacao: number,
    idPassageiro: number,
  ): Promise<Pagamento> {
    let preparacao = await this.prepararPagamento(idSolicitacao, idPassageiro);

    if (!preparacao.criadoAgora) {
      const deveReutilizar = await this.reconciliarPagamentoExistente(
        preparacao.pagamento,
      );

      if (deveReutilizar) {
        return preparacao.pagamento;
      }

      preparacao = await this.prepararPagamento(idSolicitacao, idPassageiro);

      if (!preparacao.criadoAgora) {
        return preparacao.pagamento;
      }
    }

    const { pagamento, expiraEmSegundos } = preparacao;
    let cobranca: CobrancaPix;
    try {
      cobranca = await this.abacatePayService.criarPix({
        valorCentavos: pagamento.valorCentavos,
        referencia: pagamento.referencia,
        descricao: `Carona ${pagamento.solicitacao.carona.idCarona} - solicitacao ${idSolicitacao}`,
        expiraEmSegundos,
      });
    } catch (erro) {
      const status =
        erro instanceof BadRequestException ||
        erro instanceof ServiceUnavailableException
          ? 'FALHOU'
          : 'INCERTA';

      await this.registrarStatusComTolerancia(pagamento, status);
      throw erro;
    }

    pagamento.statusCriacao = 'CONFIRMADA';
    pagamento.idProvedor = cobranca.id;
    pagamento.statusProvedor = cobranca.status;
    pagamento.pixCopiaECola = cobranca.pixCopiaECola;
    pagamento.qrCodeBase64 = cobranca.qrCodeBase64;
    pagamento.expiraEm = new Date(cobranca.expiraEm);
    pagamento.modoTeste = cobranca.modoTeste;

    try {
      return await this.pagamentosRepository.save(pagamento);
    } catch {
      await this.registrarStatusComTolerancia(pagamento, 'INCERTA');
      throw new ServiceUnavailableException(
        'A cobranca foi criada, mas nao foi possivel salvar sua confirmacao. Nao tente novamente agora',
      );
    }
  }

  async simularPagamento(
    idPagamento: number,
    idPassageiro: number,
  ): Promise<Pagamento> {
    const pagamento = await this.obterPagamento(idPagamento, idPassageiro);

    if (!pagamento.modoTeste) {
      throw new ConflictException(
        'A simulacao esta disponivel apenas no ambiente de testes',
      );
    }

    if (pagamento.statusProvedor === 'PAID') {
      return pagamento;
    }

    if (
      pagamento.statusCriacao !== 'CONFIRMADA' ||
      pagamento.statusProvedor !== 'PENDING' ||
      !pagamento.idProvedor
    ) {
      throw new ConflictException(
        'Este pagamento nao esta disponivel para simulacao',
      );
    }

    await this.abacatePayService.simularPagamento(pagamento.idProvedor);

    // O webhook continua sendo a unica fonte que confirma PAID no banco.
    return pagamento;
  }

  private async prepararPagamento(
    idSolicitacao: number,
    idPassageiro: number,
  ): Promise<PreparacaoPagamento> {
    return this.dataSource.transaction(async (manager) => {
      const solicitacoesRepository = manager.getRepository(Solicitacao);
      const pagamentosRepository = manager.getRepository(Pagamento);

      const solicitacao = await solicitacoesRepository
        .createQueryBuilder('solicitacao')
        .innerJoinAndSelect('solicitacao.carona', 'carona')
        .innerJoinAndSelect('solicitacao.passageiro', 'passageiro')
        .where('solicitacao.idSolicitacao = :idSolicitacao', {
          idSolicitacao,
        })
        .setLock('pessimistic_write', undefined, ['solicitacao'])
        .getOne();

      if (!solicitacao || solicitacao.passageiro.idUsuario !== idPassageiro) {
        throw new NotFoundException('Solicitacao nao encontrada');
      }

      if (solicitacao.status !== 'ACEITA') {
        throw new ConflictException(
          'O pagamento so pode ser criado para uma solicitacao aceita',
        );
      }

      if (solicitacao.carona.recorrente) {
        throw new ConflictException(
          'Pagamentos de caronas recorrentes ainda nao estao disponiveis',
        );
      }

      const existente = await pagamentosRepository.findOne({
        where: {
          solicitacao: { idSolicitacao },
          statusCriacao: In(STATUS_QUE_BLOQUEIAM_NOVA_TENTATIVA),
        },
        relations: { solicitacao: true },
        order: { criadoEm: 'DESC' },
      });

      if (
        existente &&
        !this.statusPermiteNovaTentativa(existente.statusProvedor)
      ) {
        return { pagamento: existente, criadoAgora: false };
      }

      const expiraEmSegundos = this.calcularExpiracaoPix(
        solicitacao.pagamentoLimiteEm,
      );

      const valorCentavos = this.converterValorParaCentavos(
        solicitacao.carona.valor,
      );
      const pagamento = pagamentosRepository.create({
        solicitacao,
        referencia: randomUUID(),
        provedor: 'ABACATEPAY',
        modoTeste: true,
        metodo: 'PIX',
        valorCentavos,
        statusCriacao: 'PREPARADA',
      });

      return {
        pagamento: await pagamentosRepository.save(pagamento),
        criadoAgora: true,
        expiraEmSegundos,
      };
    });
  }

  private converterValorParaCentavos(valor: number): number {
    const valorEmCentavos = Number(valor) * 100;
    const valorArredondado = Math.round(valorEmCentavos);

    if (
      !Number.isFinite(valorEmCentavos) ||
      !Number.isSafeInteger(valorArredondado) ||
      valorArredondado <= 0 ||
      valorArredondado > 9_999_999_999 ||
      Math.abs(valorEmCentavos - valorArredondado) > 0.000001
    ) {
      throw new ConflictException('O valor desta carona nao pode ser cobrado');
    }

    return valorArredondado;
  }

  private calcularExpiracaoPix(limitePagamento: Date | null): number {
    if (!limitePagamento) {
      throw new ConflictException(
        'O prazo de pagamento desta solicitação não foi definido',
      );
    }

    const segundos = calcularDuracaoPixSegundos(limitePagamento);

    if (segundos <= 0) {
      throw new ConflictException('O prazo para pagamento expirou');
    }

    return segundos;
  }

  private async reconciliarPagamentoExistente(
    pagamento: Pagamento,
  ): Promise<boolean> {
    if (this.statusPermiteNovaTentativa(pagamento.statusProvedor)) {
      return false;
    }

    if (pagamento.statusCriacao !== 'CONFIRMADA' || !pagamento.idProvedor) {
      return true;
    }

    const consulta = await this.abacatePayService.consultarPix(
      pagamento.idProvedor,
    );
    pagamento.statusProvedor = consulta.status;
    pagamento.expiraEm = new Date(consulta.expiraEm);
    await this.pagamentosRepository.save(pagamento);

    return !this.statusPermiteNovaTentativa(consulta.status);
  }

  private statusPermiteNovaTentativa(status: StatusPix | null): boolean {
    return (
      status !== null && STATUS_PIX_QUE_PERMITEM_NOVA_TENTATIVA.has(status)
    );
  }

  private async registrarStatusComTolerancia(
    pagamento: Pagamento,
    statusCriacao: StatusCriacaoPagamento,
  ): Promise<void> {
    pagamento.statusCriacao = statusCriacao;

    try {
      await this.pagamentosRepository.update(pagamento.idPagamento, {
        statusCriacao,
      });
    } catch {
      // Preserva o erro original. PREPARADA tambem impede uma nova cobranca.
    }
  }
}
