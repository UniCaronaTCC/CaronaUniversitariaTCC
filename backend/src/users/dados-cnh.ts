import type { LeituraCnh } from './nome-cnh-layout';

export interface DadosCnh {
  cpf: string;
  categoria: string;
  validade: string;
}

export const motivosCnh = {
  NOME_NAO_LIDO:
    'Não foi possível identificar o campo de nome completo na CNH. Isso pode ocorrer por uma limitação da leitura automática, mesmo com uma foto nítida. Confira se a frente do documento está inteira e tente novamente.',
  NOME_DIVERGENTE:
    'O nome lido não corresponde ao nome completo informado. Confira o preenchimento e a foto.',
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

export interface DiagnosticoNomeCnh {
  titulosEncontrados: number;
  linhasAceitas: number;
  parada:
    | 'TITULO_AUSENTE'
    | 'REGIAO_LIDA'
    | 'REGIAO_NAO_IDENTIFICADA'
    | 'FIM_DA_LEITURA'
    | 'OUTRO_CAMPO'
    | 'DIGITOS_NA_LINHA'
    | 'FORMATO_NAO_RECONHECIDO'
    | 'LIMITE_DE_LINHAS';
  resultado: 'NAO_EXTRAIDO' | 'DIVERGENTE' | 'CORRESPONDE';
}

export function nomeCompletoValido(nome: unknown): nome is string {
  return (
    typeof nome === 'string' &&
    nome.trim().length <= 150 &&
    /^[\p{L}]+(?:['’-][\p{L}]+)*(?:\s+[\p{L}]+(?:['’-][\p{L}]+)*)+$/u.test(
      nome.trim(),
    )
  );
}

function normalizar(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9/.-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

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
  nomeUsuario: string,
  hoje: string,
  diagnosticarNome?: (diagnostico: DiagnosticoNomeCnh) => void,
): ConferenciaCnh {
  const nome = normalizar(nomeUsuario);
  const nomeDocumento = normalizar(entrada.nome ?? '');
  diagnosticarNome?.({
    titulosEncontrados: nomeDocumento ? 1 : 0,
    linhasAceitas: nomeDocumento ? 1 : 0,
    parada: nomeDocumento ? 'REGIAO_LIDA' : 'REGIAO_NAO_IDENTIFICADA',
    resultado: !nomeDocumento
      ? 'NAO_EXTRAIDO'
      : nomeCompletoValido(nomeUsuario) && nomeDocumento === nome
        ? 'CORRESPONDE'
        : 'DIVERGENTE',
  });
  if (!nomeDocumento) return { dados: null, motivo: 'NOME_NAO_LIDO' };
  if (!nomeCompletoValido(nomeUsuario) || nomeDocumento !== nome)
    return { dados: null, motivo: 'NOME_DIVERGENTE' };
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
  return { dados: { cpf, categoria, validade } };
}
