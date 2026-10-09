export interface DadosCnh {
  cpf: string;
  categoria: string;
  validade: string;
  registroFinal: string;
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
  for (let indice = 0; indice < linhas.length; indice++) {
    const encontrado = rotulo.exec(linhas[indice]);
    if (!encontrado) continue;

    const restante = linhas[indice].slice(
      encontrado.index + encontrado[0].length,
    );
    const contexto = `${restante} ${linhas[indice + 1] ?? ''}`;
    const resultado = valor.exec(contexto);
    if (resultado) return resultado[1];
  }
  return null;
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
  const [dia, mes, ano] = valor.split('/').map(Number);
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

export function extrairDadosCnh(
  texto: string,
  nomeUsuario: string,
  hoje: string,
): DadosCnh | null {
  const linhas = texto.split(/\r?\n/).map(normalizar).filter(Boolean);

  const nome = normalizar(nomeUsuario);
  const nomeDocumento = campoAposRotulo(
    linhas,
    /\bNOME(?: E SOBRENOME)?\b/,
    /([A-Z]+(?: [A-Z]+)+)/,
  );
  if (!nome || !nomeDocumento || !nomeDocumento.includes(nome)) return null;

  const cpfLido = campoAposRotulo(
    linhas,
    /\bCPF\b/,
    /\b(\d{3}[. ]?\d{3}[. ]?\d{3}[- ]?\d{2})\b/,
  );
  const cpf = cpfLido?.replace(/\D/g, '') ?? '';
  if (!cpfValido(cpf)) return null;

  const categoria = campoAposRotulo(
    linhas,
    /\b(?:CATEGORIA|CAT\.? HAB\.?)(?=\s|$)/,
    /\b(A?[BCDE])\b/,
  );
  if (!categoria) return null;

  const validadeLida = campoAposRotulo(
    linhas,
    /\bVALIDADE\b/,
    /\b(\d{2}\/\d{2}\/\d{4})\b/,
  );
  const validade = validadeLida ? dataIso(validadeLida) : null;
  if (!validade || validade < hoje) return null;

  const registro = campoAposRotulo(linhas, /\bREGISTRO\b/, /\b(\d{11})\b/);
  if (!registro) return null;

  return {
    cpf,
    categoria,
    validade,
    registroFinal: registro.slice(-4),
  };
}
