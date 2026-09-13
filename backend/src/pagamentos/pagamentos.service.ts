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
import type { CobrancaPix } from './abacatepay.types';
import { Pagamento, StatusCriacaoPagamento } from './pagamento.entity';

const STATUS_QUE_BLOQUEIAM_NOVA_TENTATIVA: StatusCriacaoPagamento[] = [
  'PREPARADA',
  'CONFIRMADA',
  'INCERTA',
];

@Injectable()
export class PagamentosService {
  constructor(
    @InjectRepository(Pagamento)
    private readonly pagamentosRepository: Repository<Pagamento>,
    private readonly dataSource: DataSource,
    private readonly abacatePayService: AbacatePayService,
  ) {}

  async criarOuObterPix(
    idSolicitacao: number,
    idPassageiro: number,
  ): Promise<Pagamento> {
    const { pagamento, criadoAgora } = await this.prepararPagamento(
      idSolicitacao,
      idPassageiro,
    );

    if (!criadoAgora) {
      return pagamento;
    }

    let cobranca: CobrancaPix;
    try {
      cobranca = await this.abacatePayService.criarPix({
        valorCentavos: pagamento.valorCentavos,
        referencia: pagamento.referencia,
        descricao: `Carona ${pagamento.solicitacao.carona.idCarona} - solicitacao ${idSolicitacao}`,
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

  private async prepararPagamento(
    idSolicitacao: number,
    idPassageiro: number,
  ): Promise<{ pagamento: Pagamento; criadoAgora: boolean }> {
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

      if (existente) {
        return { pagamento: existente, criadoAgora: false };
      }

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
