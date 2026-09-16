const UMA_HORA_EM_MILISSEGUNDOS = 60 * 60 * 1000;
const QUINZE_MINUTOS_EM_MILISSEGUNDOS = 15 * 60 * 1000;

export const DURACAO_MAXIMA_PIX_SEGUNDOS = 30 * 60;

export function calcularLimitePagamento(
  dataInicio: string,
  horario: string,
  agora = new Date(),
): Date {
  const horarioCompleto = /^\d{2}:\d{2}$/.test(horario)
    ? `${horario}:00`
    : horario;
  const inicioCarona = new Date(`${dataInicio}T${horarioCompleto}-03:00`);

  if (!Number.isFinite(inicioCarona.getTime())) {
    throw new RangeError('Data ou horario da carona invalido');
  }

  const limiteAceite = agora.getTime() + UMA_HORA_EM_MILISSEGUNDOS;
  const limiteCarona = inicioCarona.getTime() - QUINZE_MINUTOS_EM_MILISSEGUNDOS;

  return new Date(Math.min(limiteAceite, limiteCarona));
}

export function calcularDuracaoPixSegundos(
  limitePagamento: Date,
  agora = new Date(),
): number {
  const segundosRestantes = Math.floor(
    (limitePagamento.getTime() - agora.getTime()) / 1000,
  );

  return Math.min(DURACAO_MAXIMA_PIX_SEGUNDOS, segundosRestantes);
}
