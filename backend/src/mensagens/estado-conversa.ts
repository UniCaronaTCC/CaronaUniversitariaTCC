import type { Solicitacao } from '../solicitacoes/solicitacao.entity';

export function conversaEncerrada(solicitacao: Solicitacao): boolean {
  return (
    solicitacao.status !== 'ACEITA' ||
    !['ATIVA', 'LOTADA', 'EM_ANDAMENTO'].includes(solicitacao.carona.status)
  );
}
