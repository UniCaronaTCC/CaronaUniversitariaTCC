import { EntityManager, In } from 'typeorm';
import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';

// O registro permanece no banco. Só a participação no percurso é derivada
// das reservas atuais, sem apagar a origem da sugestão ou o histórico.
export async function filtrarPontosDoPercurso(
  manager: EntityManager,
  caronas: Carona[],
): Promise<Carona[]> {
  const ativas = caronas.filter(
    (c) =>
      ['ATIVA', 'LOTADA', 'EM_ANDAMENTO'].includes(c.status) &&
      c.pontosEmbarque?.some((p) => p.sugeridoPorPassageiro),
  );
  if (!ativas.length) return caronas;

  const reservas = await manager.getRepository(Solicitacao).find({
    where: {
      carona: { idCarona: In(ativas.map((c) => c.idCarona)) },
      status: 'ACEITA',
    },
    relations: { pontoEmbarque: true },
  });
  const utilizados = new Set(
    reservas.map((r) => r.pontoEmbarque?.idPontoEmbarque),
  );
  for (const carona of ativas) {
    carona.pontosEmbarque = carona.pontosEmbarque.filter(
      (p) =>
        !p.sugeridoPorPassageiro ||
        p.percorridoEm != null ||
        utilizados.has(p.idPontoEmbarque),
    );
  }
  return caronas;
}

export async function consultarPontosDoPercurso(
  manager: EntityManager,
  idCarona: number,
  status: string,
): Promise<PontoEmbarque[]> {
  const pontos = await manager.getRepository(PontoEmbarque).find({
    where: { carona: { idCarona } },
    order: { ordem: 'ASC', idPontoEmbarque: 'ASC' },
  });
  const [carona] = await filtrarPontosDoPercurso(manager, [
    Object.assign(new Carona(), { idCarona, status, pontosEmbarque: pontos }),
  ]);
  return carona.pontosEmbarque;
}
