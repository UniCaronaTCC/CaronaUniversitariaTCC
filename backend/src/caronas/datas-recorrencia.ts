import { BadRequestException } from '@nestjs/common';

export const DIAS_SEMANA = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];

export function dataEmBrasilia(agora: Date): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(agora);
}

export function validarData(data: string): void {
  const instante = new Date(`${data}T12:00:00Z`);
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(data) ||
    !Number.isFinite(instante.getTime()) ||
    instante.toISOString().slice(0, 10) !== data
  ) {
    throw new BadRequestException('Data inválida');
  }
}

export function datasRecorrencia(
  dados: {
    dataInicio: string;
    dataFim: string | null;
    diasSemana: string[] | null;
    horario: string;
  },
  agora = new Date(),
): string[] {
  const hoje = dataEmBrasilia(agora);
  const inicio = dados.dataInicio > hoje ? dados.dataInicio : hoje;
  const cursor = new Date(`${inicio}T12:00:00Z`);
  const datas: string[] = [];
  for (let i = 0; i < 14; i++, cursor.setUTCDate(cursor.getUTCDate() + 1)) {
    const data = cursor.toISOString().slice(0, 10);
    if (dados.dataFim && data > dados.dataFim) break;
    if (!dados.diasSemana?.includes(DIAS_SEMANA[cursor.getUTCDay()])) continue;
    // Não publica partidas que já passaram. Mantém o fuso adotado pelo app.
    if (new Date(`${data}T${dados.horario}-03:00`).getTime() <= agora.getTime())
      continue;
    datas.push(data);
  }
  return datas;
}
