import type { LeituraCnh } from './nome-cnh-layout';

export interface DadosCnh {
  cpf: string;
  categoria: string;
  validade: string;
  registroFinal: string;
}

export const motivosCnh = {
  NOME_NAO_LIDO:
    'Não conseguimos ler o nome completo na CNH. Fotografe essa parte com nitidez.',
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
  REGISTRO_NAO_LIDO: 'Não conseguimos ler o número de registro da CNH.',
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

function campoAposRotulo(
  linhas: string[],
  rotulo: RegExp,
  valor: RegExp,
): string | null {
  const campos: string[] = [];
  for (let indice = 0; indice < linhas.length; indice++) {
    const encontrado = rotulo.exec(linhas[indice]);
    if (!encontrado) continue;

    // Não deduzimos colunas a partir do texto: outro rótulo antes deste
    // torna a associação ambígua. Aceita apenas numeração/prefixo do campo.
    const prefixo = linhas[indice].slice(0, encontrado.index).trim();
    if (!/^(?:N[O.]?\s*)?(?:\d{1,2}[A-E]?\s*)?$/.test(prefixo)) return null;
    const restante = linhas[indice]
      .slice(encontrado.index + encontrado[0].length)
      .trim();
    const indiceValor = restante ? indice : indice + 1;
    const contexto = restante || linhas[indiceValor] || '';
    // A expressão deve casar com o valor inteiro, nunca com um trecho
    // de outro campo. Mais uma linha numérica também exige nova captura.
    const resultado = valor.exec(contexto);
    if (!resultado || /^[\d\s/.-]+$/.test(linhas[indiceValor + 1] ?? ''))
      return null;
    campos.push(resultado[1]);
  }
  return campos.length === 1 ? campos[0] : null;
}

function cpfValido(cpf: string): boolean {
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
  entrada: string | LeituraCnh,
  nomeUsuario: string,
  hoje: string,
  diagnosticarNome?: (diagnostico: DiagnosticoNomeCnh) => void,
): ConferenciaCnh {
  const texto = typeof entrada === 'string' ? entrada : entrada.texto;
  const linhas = texto.split(/\r?\n/).map(normalizar).filter(Boolean);

  const nome = normalizar(nomeUsuario);
  // Junta somente linhas do nome, parando antes de outros campos.
  const indiceNome = linhas.findIndex((linha) =>
    /\bNOME(?: E SOBRENOME)?\b/.test(linha),
  );
  const partes: string[] = [];
  const titulosEncontrados = linhas.filter((linha) =>
    /\bNOME(?: E SOBRENOME)?\b/.test(linha),
  ).length;
  let parada: DiagnosticoNomeCnh['parada'] = 'TITULO_AUSENTE';
  if (indiceNome >= 0) {
    parada =
      linhas.length > indiceNome + 4 ? 'LIMITE_DE_LINHAS' : 'FIM_DA_LEITURA';
    const primeira = linhas[indiceNome]
      .replace(/^.*?\bNOME(?: E SOBRENOME)?\b/, '')
      .trim();
    const candidatos = [
      primeira,
      ...linhas.slice(indiceNome + 1, indiceNome + 4),
    ];
    for (const linha of candidatos) {
      if (!linha) continue;
      if (
        /\b(CPF|REGISTRO|VALIDADE|CATEGORIA|CAT|FILIACAO|NASCIMENTO|DATA|DOC|IDENTIDADE|ASSINATURA|NACIONALIDADE|PERMISSAO)\b/.test(
          linha,
        )
      ) {
        parada = 'OUTRO_CAMPO';
        break;
      }
      if (!/^[A-Z]+(?:[.'’\- ]+[A-Z]+)*$/.test(linha)) {
        parada = /\d/.test(linha)
          ? 'DIGITOS_NA_LINHA'
          : 'FORMATO_NAO_RECONHECIDO';
        break;
      }
      partes.push(linha);
    }
  }
  const porLayout = typeof entrada !== 'string';
  const nomeDocumento = porLayout
    ? normalizar(entrada.nome ?? '')
    : partes.join(' ');
  diagnosticarNome?.({
    titulosEncontrados,
    linhasAceitas: porLayout ? (nomeDocumento ? 1 : 0) : partes.length,
    parada: porLayout
      ? nomeDocumento
        ? 'REGIAO_LIDA'
        : 'REGIAO_NAO_IDENTIFICADA'
      : parada,
    resultado: !nomeDocumento
      ? 'NAO_EXTRAIDO'
      : nomeCompletoValido(nomeUsuario) && nomeDocumento === nome
        ? 'CORRESPONDE'
        : 'DIVERGENTE',
  });
  if (!nomeDocumento) return { dados: null, motivo: 'NOME_NAO_LIDO' };
  if (!nomeCompletoValido(nomeUsuario) || nomeDocumento !== nome) {
    return { dados: null, motivo: 'NOME_DIVERGENTE' };
  }

  const cpfLido = campoAposRotulo(linhas, /\bCPF\b/, /^(\d[\d .-]*\d)$/);
  const cpf = cpfLido?.replace(/\D/g, '') ?? '';
  if (!cpfLido) return { dados: null, motivo: 'CPF_NAO_LIDO' };
  if (!cpfValido(cpf)) return { dados: null, motivo: 'CPF_INVALIDO' };

  const categoria = campoAposRotulo(
    linhas,
    /\b(?:CATEGORIA|CAT\.?\s*HAB\.?)(?=\s|$)/,
    /^(A?[BCDE]|A|ACC)$/,
  );
  if (!categoria) return { dados: null, motivo: 'CATEGORIA_NAO_LIDA' };
  if (!/^A?[BCDE]$/.test(categoria))
    return { dados: null, motivo: 'CATEGORIA_INCOMPATIVEL' };

  const validadeLida = campoAposRotulo(
    linhas,
    /\bVALIDADE\b/,
    /^(\d{2}\s*([/.])\s*\d{2}\s*\2\s*\d{4})$/,
  );
  const validade = validadeLida ? dataIso(validadeLida) : null;
  if (!validade) return { dados: null, motivo: 'VALIDADE_NAO_LIDA' };
  if (validade < hoje) return { dados: null, motivo: 'CNH_VENCIDA' };

  const registro = campoAposRotulo(
    linhas,
    /\bREGISTRO\b/,
    /^(\d(?:\s*\d){10})$/,
  )?.replace(/\s/g, '');
  if (!registro) return { dados: null, motivo: 'REGISTRO_NAO_LIDO' };

  return {
    dados: {
      cpf,
      categoria,
      validade,
      registroFinal: registro.slice(-4),
    },
  };
}

export function extrairDadosCnh(
  texto: string,
  nome: string,
  hoje: string,
): DadosCnh | null {
  return conferirDadosCnh(texto, nome, hoje).dados;
}
