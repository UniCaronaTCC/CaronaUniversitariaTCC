import type { LeituraCnh } from './nome-cnh-layout';

export interface DadosCnh {
  nome: string;
  registro: string;
  cpf: string;
  categoria: string;
  validade: string;
}

export const motivosCnh = {
  NOME_NAO_LIDO:
    'O nome não foi identificado. Envie uma foto que mostre o campo NOME da CNH.',
  REGISTRO_NAO_LIDO:
    'O número de registro não foi identificado. Envie uma foto que mostre o campo REGISTRO da CNH.',
  CPF_NAO_LIDO: 'Não conseguimos ler o CPF na CNH. Refaça a foto dessa parte.',
  CPF_INVALIDO:
    'O CPF lido não passou na conferência. Refaça a foto com os números nítidos.',
  CATEGORIA_NAO_LIDA: 'Não conseguimos ler a categoria da CNH.',
  CATEGORIA_INCOMPATIVEL:
    'A categoria lida não permite dirigir automóveis. Confira a foto da categoria.',
  VALIDADE_NAO_LIDA:
    'Não conseguimos identificar com segurança a validade da CNH. Fotografe o campo de validade com nitidez.',
  CNH_VENCIDA:
    'A data de validade lida está vencida. Confira a validade e a foto.',
} as const;

type ConferenciaCnh =
  | { dados: DadosCnh; motivo?: never }
  | { dados: null; motivo: keyof typeof motivosCnh };

export function cpfValido(cpf: string): boolean {
  if (!/^\d{11}$/.test(cpf) || /^(\d)\1{10}$/.test(cpf)) return false;

  for (const tamanho of [9, 10]) {
    const soma = [...cpf.slice(0, tamanho)].reduce(
      (total, digito, indice) =>
        total + Number(digito) * (tamanho + 1 - indice),
      0,
    );
    const resto = (soma * 10) % 11;
    if (Number(cpf[tamanho]) !== (resto === 10 ? 0 : resto)) return false;
  }
  return true;
}

function dataIso(valor: string): string | null {
  const [dia, mes, ano] = valor.split(/[/.]/).map(Number);
  const data = new Date(Date.UTC(ano, mes - 1, dia));
  if (
    data.getUTCFullYear() !== ano ||
    data.getUTCMonth() + 1 !== mes ||
    data.getUTCDate() !== dia
  ) {
    return null;
  }
  return `${ano.toString().padStart(4, '0')}-${mes.toString().padStart(2, '0')}-${dia.toString().padStart(2, '0')}`;
}

export function conferirDadosCnh(
  entrada: LeituraCnh,
  hoje: string,
): ConferenciaCnh {
  // Exigimos os dados extraídos, sem comparar o nome com perfil ou texto digitado.
  const nome = entrada.nome?.trim();
  if (!nome || nome.length > 150)
    return { dados: null, motivo: 'NOME_NAO_LIDO' };
  const registro = entrada.registro;
  if (!registro || !/^\d{11}$/.test(registro))
    return { dados: null, motivo: 'REGISTRO_NAO_LIDO' };
  const campos = entrada.campos;
  const cpfLido = campos?.cpf;
  if (!cpfLido) return { dados: null, motivo: 'CPF_NAO_LIDO' };
  if (!/^[\d .-]+$/.test(cpfLido))
    return { dados: null, motivo: 'CPF_INVALIDO' };
  const cpf = cpfLido.replace(/\D/g, '');
  if (!cpfValido(cpf)) return { dados: null, motivo: 'CPF_INVALIDO' };
  const categoria = campos?.categoria;
  if (!categoria) return { dados: null, motivo: 'CATEGORIA_NAO_LIDA' };
  if (!/^A?[BCDE]$/.test(categoria))
    return { dados: null, motivo: 'CATEGORIA_INCOMPATIVEL' };
  const validadeLida = campos?.validade;
  const validade =
    validadeLida && /^\d{2}\s*([/.])\s*\d{2}\s*\1\s*\d{4}$/.test(validadeLida)
      ? dataIso(validadeLida)
      : null;
  if (!validade) return { dados: null, motivo: 'VALIDADE_NAO_LIDA' };
  if (validade < hoje) return { dados: null, motivo: 'CNH_VENCIDA' };
  return { dados: { nome, registro, cpf, categoria, validade } };
}
