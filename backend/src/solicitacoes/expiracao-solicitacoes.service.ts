import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { DataSource } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
import { AbacatePayService } from '../pagamentos/abacatepay.service';
import type { ConsultaPix } from '../pagamentos/abacatepay.types';
import { Pagamento } from '../pagamentos/pagamento.entity';
import { Solicitacao } from './solicitacao.entity';

const INTERVALO_VERIFICACAO_MS = 30_000;
const STATUS_FINAIS_SEM_PAGAMENTO = new Set(['EXPIRED', 'CANCELLED', 'FAILED']);

@Injectable()
export class ExpiracaoSolicitacoesService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(ExpiracaoSolicitacoesService.name);
  private timer: NodeJS.Timeout | null = null;
  private emExecucao = false;

  constructor(
    private readonly dataSource: DataSource,
    private readonly abacatePayService: AbacatePayService,
  ) {}

  onModuleInit(): void {
    void this.expirarVencidas();
    this.timer = setInterval(
      () => void this.expirarVencidas(),
      INTERVALO_VERIFICACAO_MS,
    );
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async expirarVencidas(): Promise<void> {
    if (this.emExecucao) return;
    this.emExecucao = true;

    try {
      const agora = new Date();
      const candidatas = await this.dataSource.query<
        Array<{ id_solicitacao: number }>
      >(
        `SELECT solicitacao.id_solicitacao
         FROM unicarona.solicitacoes solicitacao
         WHERE solicitacao.status = 'ACEITA'
           AND solicitacao.pagamento_limite_em <= $1
           AND NOT EXISTS (
             SELECT 1 FROM unicarona.pagamentos pagamento
             WHERE pagamento.id_solicitacao = solicitacao.id_solicitacao
               AND pagamento.status_provedor = 'PAID'
           )
         ORDER BY solicitacao.pagamento_limite_em`,
        [agora],
      );

      for (const candidata of candidatas) {
        try {
          await this.expirarUma(candidata.id_solicitacao, agora);
        } catch (erro) {
          this.logger.error(
            `Falha ao verificar solicitacao ${candidata.id_solicitacao}`,
            erro,
          );
        }
      }
    } catch (erro) {
      this.logger.error('Falha ao buscar solicitacoes vencidas', erro);
    } finally {
      this.emExecucao = false;
    }
  }

  private async expirarUma(idSolicitacao: number, agora: Date): Promise<void> {
    const tentativas = await this.dataSource.getRepository(Pagamento).find({
      where: { solicitacao: { idSolicitacao } },
    });
    const consultas = new Map<number, ConsultaPix>();

    for (const tentativa of tentativas) {
      if (tentativa.statusProvedor === 'PAID') return;
      if (
        tentativa.statusCriacao === 'PREPARADA' ||
        tentativa.statusCriacao === 'INCERTA'
      )
        return;

      if (tentativa.statusProvedor === 'PENDING') {
        if (!tentativa.idProvedor) return;

        try {
          const consulta = await this.abacatePayService.consultarPix(
            tentativa.idProvedor,
          );
          if (!STATUS_FINAIS_SEM_PAGAMENTO.has(consulta.status)) return;
          consultas.set(tentativa.idPagamento, consulta);
        } catch {
          // Sem certeza sobre o provedor, a vaga continua reservada.
          return;
        }
      } else if (
        tentativa.statusCriacao !== 'FALHOU' &&
        !STATUS_FINAIS_SEM_PAGAMENTO.has(tentativa.statusProvedor ?? '')
      ) {
        return;
      }
    }

    await this.dataSource.transaction(async (manager) => {
      const solicitacoesRepository = manager.getRepository(Solicitacao);
      const pagamentosRepository = manager.getRepository(Pagamento);
      const caronasRepository = manager.getRepository(Carona);
      const solicitacao = await solicitacoesRepository
        .createQueryBuilder('solicitacao')
        .innerJoinAndSelect('solicitacao.carona', 'carona')
        .where('solicitacao.idSolicitacao = :idSolicitacao', { idSolicitacao })
        .setLock('pessimistic_write', undefined, ['solicitacao', 'carona'])
        .getOne();

      if (
        !solicitacao ||
        solicitacao.status !== 'ACEITA' ||
        !solicitacao.pagamentoLimiteEm ||
        solicitacao.pagamentoLimiteEm.getTime() > agora.getTime()
      )
        return;

      const pagamentos = await pagamentosRepository
        .createQueryBuilder('pagamento')
        .where('pagamento.id_solicitacao = :idSolicitacao', { idSolicitacao })
        .setLock('pessimistic_write')
        .getMany();

      for (const pagamento of pagamentos) {
        if (pagamento.statusProvedor === 'PAID') return;
        if (
          pagamento.statusCriacao === 'PREPARADA' ||
          pagamento.statusCriacao === 'INCERTA'
        )
          return;

        if (pagamento.statusProvedor === 'PENDING') {
          const consulta = consultas.get(pagamento.idPagamento);
          if (!consulta || consulta.id !== pagamento.idProvedor) return;
          pagamento.statusProvedor = consulta.status;
          pagamento.expiraEm = new Date(consulta.expiraEm);
          await pagamentosRepository.save(pagamento);
        } else if (
          pagamento.statusCriacao !== 'FALHOU' &&
          !STATUS_FINAIS_SEM_PAGAMENTO.has(pagamento.statusProvedor ?? '')
        ) {
          return;
        }
      }

      solicitacao.status = 'EXPIRADA';
      solicitacao.carona.vagas = Math.min(4, solicitacao.carona.vagas + 1);
      if (solicitacao.carona.status === 'LOTADA') {
        solicitacao.carona.status = 'ATIVA';
      }

      await caronasRepository.save(solicitacao.carona);
      await solicitacoesRepository.save(solicitacao);
    });
  }
}
