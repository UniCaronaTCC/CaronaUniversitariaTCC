import { ConflictException } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { exigirPagamentosParaInicio } from './pagamentos-inicio';

describe('Pagamento simulado antes da partida', () => {
  function preparar(quantidadePendente: number) {
    const consulta = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getCount: jest.fn().mockResolvedValue(quantidadePendente),
    };
    const manager = {
      getRepository: () => ({ createQueryBuilder: () => consulta }),
    } as unknown as EntityManager;
    return { manager, consulta };
  }

  it('permite iniciar quando todos os aceitos estão pagos ou não há passageiros', async () => {
    const { manager, consulta } = preparar(0);
    await expect(
      exigirPagamentosParaInicio(manager, 10),
    ).resolves.toBeUndefined();
    expect(consulta.where).toHaveBeenCalledWith(
      'solicitacao.id_carona = :idCarona',
      { idCarona: 10 },
    );
    expect(consulta.andWhere).toHaveBeenCalledWith(
      "solicitacao.status = 'ACEITA'",
    );
    expect(consulta.andWhere).toHaveBeenCalledWith(
      expect.stringContaining("pagamento.status_provedor = 'PAID'"),
    );
  });

  it.each([1, 3])(
    'bloqueia %i reservas sem confirmação, sem expulsar quem ainda pode pagar',
    async (quantidade) => {
      const { manager } = preparar(quantidade);
      await expect(
        exigirPagamentosParaInicio(manager, 10),
      ).rejects.toBeInstanceOf(ConflictException);
    },
  );

  it('falha de consulta não autoriza iniciar sem conferir', async () => {
    const { manager, consulta } = preparar(0);
    consulta.getCount.mockRejectedValue(new Error('Banco indisponível'));
    await expect(exigirPagamentosParaInicio(manager, 10)).rejects.toThrow(
      'Banco indisponível',
    );
  });
});
