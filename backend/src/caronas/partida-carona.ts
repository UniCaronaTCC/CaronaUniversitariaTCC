import type { Carona } from './carona.entity';

// A oferta publica termina na partida, sem encerrar a viagem dos participantes.
export const PARTIDA_FUTURA_SQL = `(carona.dataInicio + carona.horario) >
  (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')`;

export function partidaNoFuturo(
  carona: Pick<Carona, 'dataInicio' | 'horario'>,
  agora = new Date(),
): boolean {
  const partida = new Date(`${carona.dataInicio}T${carona.horario}-03:00`);
  return partida.getTime() > agora.getTime();
}
