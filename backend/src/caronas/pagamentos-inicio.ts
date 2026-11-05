import { ConflictException } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';

// A carona deve estar bloqueada pelo chamador: aceite e cancelamento usam
// a mesma linha, impedindo que os participantes mudem durante a partida.
export async function exigirPagamentosParaInicio(
  manager: EntityManager,
  idCarona: number,
): Promise<void> {
  const pendentes = await manager
    .getRepository(Solicitacao)
    .createQueryBuilder('solicitacao')
    .where('solicitacao.id_carona = :idCarona', { idCarona })
    .andWhere("solicitacao.status = 'ACEITA'")
    .andWhere(
      `NOT EXISTS (
      SELECT 1 FROM unicarona.pagamentos pagamento
      WHERE pagamento.id_solicitacao = solicitacao.id_solicitacao
        AND pagamento.status_provedor = 'PAID'
    )`,
    )
    .getCount();

  if (pendentes > 0) {
    throw new ConflictException({
      codigo: 'PAGAMENTOS_PENDENTES',
      message:
        'Há passageiros com pagamento pendente. Aguarde a confirmação da simulação ou a resolução das reservas antes de iniciar.',
    });
  }
}
