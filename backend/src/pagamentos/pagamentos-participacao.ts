import { ConflictException } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { Pagamento } from './pagamento.entity';

export async function exigirParticipacaoCancelavel(
  manager: EntityManager,
  idSolicitacao: number,
): Promise<void> {
  // Bloqueia também tentativas pendentes para ordenar cancelamento e webhook.
  const pagamentos = await manager
    .getRepository(Pagamento)
    .createQueryBuilder('pagamento')
    .where('pagamento.id_solicitacao = :idSolicitacao', { idSolicitacao })
    .setLock('pessimistic_write')
    .getMany();
  if (
    pagamentos.some((p) => p.statusProvedor === 'PAID' && !p.estornoSimuladoEm)
  ) {
    throw new ConflictException({
      codigo: 'PARTICIPACAO_PAGA',
      message:
        'Não é possível cancelar individualmente uma participação com pagamento confirmado.',
    });
  }
}
