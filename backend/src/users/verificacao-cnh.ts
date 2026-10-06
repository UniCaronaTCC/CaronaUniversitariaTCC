import type { User } from './user.entity';

type DadosCnhParaOferta = Pick<
  User,
  'statusVerificacaoCnh' | 'cnhCategoria' | 'cnhValidade'
>;

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
