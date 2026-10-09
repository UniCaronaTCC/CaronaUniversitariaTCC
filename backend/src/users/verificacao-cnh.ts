import type { User } from './user.entity';

type DadosCnhParaOferta = Pick<
  User,
  'statusVerificacaoCnh' | 'cnhCategoria' | 'cnhValidade'
>;

export function hojeEmSaoPaulo(agora = new Date()): string {
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(agora);
  const obter = (tipo: string) =>
    partes.find((parte) => parte.type === tipo)!.value;
  return `${obter('year')}-${obter('month')}-${obter('day')}`;
}

export function cnhPermiteOferecerCarona(
  dados: DadosCnhParaOferta,
  hoje: string,
): boolean {
  if (dados.statusVerificacaoCnh !== 'APROVADA') return false;

  const categoria = dados.cnhCategoria?.trim().toUpperCase();
  if (!categoria || !/^(A?[BCDE])$/.test(categoria)) return false;

  // Colunas DATE do PostgreSQL chegam ao TypeORM como YYYY-MM-DD.
  const validade = dados.cnhValidade;
  return Boolean(
    validade &&
    /^\d{4}-\d{2}-\d{2}$/.test(validade) &&
    /^\d{4}-\d{2}-\d{2}$/.test(hoje) &&
    validade >= hoje,
  );
}
