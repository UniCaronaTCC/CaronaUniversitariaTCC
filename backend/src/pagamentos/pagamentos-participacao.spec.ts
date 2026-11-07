import { EntityManager } from 'typeorm';
import { Pagamento } from './pagamento.entity';
import { exigirParticipacaoCancelavel } from './pagamentos-participacao';

describe('Cancelamento individual com pagamento', () => {
  function preparar(pagamentos: Partial<Pagamento>[] = []) {
    const consulta = {
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue(pagamentos),
    };
    const manager = {
      getRepository: () => ({ createQueryBuilder: () => consulta }),
    } as unknown as EntityManager;
    return { manager, consulta };
  }

  it.each([
    { pagamentos: [] },
    {
      pagamentos: [
        {
          statusProvedor: 'PAID',
          estornoSimuladoEm: new Date('2026-11-06T12:00:00Z'),
        },
      ],
    },
  ])(
    'permite cancelar sem pagamento atual, ignorando estorno antigo: %j',
    async ({ pagamentos }) => {
      const { manager, consulta } = preparar(
        pagamentos as Partial<Pagamento>[],
      );
      await expect(
        exigirParticipacaoCancelavel(manager, 20),
      ).resolves.toBeUndefined();
      expect(consulta.setLock).toHaveBeenCalledWith('pessimistic_write');
      expect(consulta.where).toHaveBeenCalledWith(
        'pagamento.id_solicitacao = :idSolicitacao',
        { idSolicitacao: 20 },
      );
    },
  );

  it('falha de consulta não permite cancelar sem conferir', async () => {
    const { manager, consulta } = preparar();
    consulta.getMany.mockRejectedValue(new Error('indisponível'));
    await expect(exigirParticipacaoCancelavel(manager, 20)).rejects.toThrow(
      'indisponível',
    );
  });
});
