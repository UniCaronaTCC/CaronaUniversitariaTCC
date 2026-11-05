import { EntityManager, In } from 'typeorm';
import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { filtrarPontosDoPercurso } from './pontos-percurso';

describe('Paradas vinculadas às reservas', () => {
  const ponto = (id: number, sugerido = true) =>
    Object.assign(new PontoEmbarque(), {
      idPontoEmbarque: id,
      ordem: id,
      sugeridoPorPassageiro: sugerido,
    });

  async function percurso(
    reservas: Partial<Solicitacao>[],
    status = 'ATIVA',
    percorrido = false,
  ) {
    const original = ponto(1, false);
    const sugerido = ponto(2);
    if (percorrido) sugerido.percorridoEm = new Date();
    const carona = Object.assign(new Carona(), {
      idCarona: 10,
      status,
      pontosEmbarque: [original, sugerido],
    });
    const find = jest
      .fn()
      .mockResolvedValue(reservas.filter((r) => r.status === 'ACEITA'));
    const manager = {
      getRepository: () => ({ find }),
    } as unknown as EntityManager;
    await filtrarPontosDoPercurso(manager, [carona]);
    return { carona, find, sugerido };
  }

  it.each([
    'CANCELADA_PASSAGEIRO',
    'CANCELADA_MOTORISTA',
    'EXPIRADA',
    'PENDENTE',
  ])(
    'retira apenas a parada sugerida sem reserva válida (%s)',
    async (status) => {
      const { carona } = await percurso([{ status, pontoEmbarque: ponto(2) }]);
      expect(carona.pontosEmbarque.map((p) => p.idPontoEmbarque)).toEqual([1]);
    },
  );

  it('preserva o ponto compartilhado quando quem sugeriu desiste', async () => {
    const { carona, find } = await percurso([
      {
        status: 'CANCELADA_PASSAGEIRO',
        tipoPontoEmbarque: 'NOVO_SOLICITADO',
        pontoEmbarque: ponto(2),
      },
      {
        status: 'ACEITA',
        tipoPontoEmbarque: 'EXISTENTE',
        pontoEmbarque: ponto(2),
      },
    ]);
    expect(carona.pontosEmbarque).toHaveLength(2);
    expect(find).toHaveBeenCalledWith({
      where: { carona: { idCarona: In([10]) }, status: 'ACEITA' },
      relations: { pontoEmbarque: true },
    });
  });

  it('mantém a reserva aceita mesmo enquanto aguarda pagamento', async () => {
    const { carona } = await percurso([
      { status: 'ACEITA', pagamentoConfirmado: false, pontoEmbarque: ponto(2) },
    ]);
    expect(carona.pontosEmbarque).toHaveLength(2);
  });

  it('conserva a origem do ponto mesmo se a solicitação original for reutilizada', async () => {
    const { carona, sugerido } = await percurso([]);
    expect(carona.pontosEmbarque).toHaveLength(1);
    expect(sugerido.sugeridoPorPassageiro).toBe(true);
  });

  it('não apaga pontos já percorridos nem altera o histórico encerrado', async () => {
    expect(
      (await percurso([], 'EM_ANDAMENTO', true)).carona.pontosEmbarque,
    ).toHaveLength(2);
    const encerrada = await percurso([], 'FINALIZADA');
    expect(encerrada.carona.pontosEmbarque).toHaveLength(2);
    expect(encerrada.find).not.toHaveBeenCalled();
  });
});
