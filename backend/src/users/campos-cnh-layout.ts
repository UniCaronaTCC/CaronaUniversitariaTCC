import type { Block, Word } from 'tesseract.js';

export type CampoCnh = 'nome' | 'cpf' | 'validade' | 'categoria';
export type CamposCnh = Record<Exclude<CampoCnh, 'nome'>, string | null>;
export interface RegiaoCnh {
  left: number;
  top: number;
  width: number;
  height: number;
}

const normalizar = (s: string) =>
  s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase();
const rotulo = (s: string) => normalizar(s).replace(/[^A-Z]/g, '');
const padroes: Record<CampoCnh, RegExp> = {
  nome: /^NOME$/,
  cpf: /^(?:D)?CPF$/,
  validade: /^(?:B)?VALIDADE$/,
  categoria: /^(?:CATEGORIA|CAT|[SG]?CAT[HM]AB)$/,
};
const outro =
  /^(?:NOME|CPF|REGISTRO|VALIDADE|CAT|CATHAB|HAB|CATEGORIA|DATA|NASCIMENTO|FILIACAO|NACIONALIDADE|IDENTIDADE|DOC|ACC|HABILITACAO)$/;
const linhas = (blocos: Block[] | null) =>
  (blocos ?? []).flatMap((b) => b.paragraphs.flatMap((p) => p.lines));
const limparBorda = (s: string) =>
  s
    .trim()
    .replace(/^[|()[\]{}]+|[|()[\]{}]+$/g, '')
    .trim();

// Rótulos orientam o recorte; nenhuma coordenada depende de uma foto específica.
export function regiaoDoCampo(
  blocos: Block[] | null,
  campo: CampoCnh,
  largura: number,
  altura: number,
): RegiaoCnh | null {
  const palavras = linhas(blocos).flatMap((l) => l.words);
  const titulos = palavras.filter((p) => padroes[campo].test(rotulo(p.text)));
  if (titulos.length !== 1) return null;
  const titulo = titulos[0];
  const b = titulo.bbox;
  const h = b.y1 - b.y0;
  if (h <= 0) return null;
  const vizinhos = palavras.filter(
    (p) =>
      p !== titulo &&
      p.bbox.x0 > b.x1 &&
      Math.abs(p.bbox.y0 - b.y0) < h &&
      outro.test(rotulo(p.text)) &&
      !(campo === 'categoria' && rotulo(p.text) === 'HAB'),
  );
  const left = Math.max(
    0,
    Math.floor(
      b.x0 - h * (campo === 'nome' ? 4 : campo === 'categoria' ? 1 : 3),
    ),
  );
  const right = Math.min(
    largura,
    b.x1 + h * (campo === 'nome' ? 40 : campo === 'cpf' ? 14 : 3),
    ...vizinhos.map((p) => p.bbox.x0 - h * 2),
  );
  const top = Math.max(0, Math.floor(b.y0 - h / 2));
  const abaixo = palavras.filter(
    (p) =>
      p.bbox.y0 > b.y1 + h &&
      p.bbox.x0 < right &&
      p.bbox.x1 > left &&
      outro.test(rotulo(p.text)),
  );
  const bottom = Math.min(
    altura,
    b.y1 + h * 3,
    ...abaixo.map((p) => p.bbox.y0 - h / 2),
  );
  const width = Math.floor(right) - left;
  const height = Math.floor(bottom) - top;
  const cortaValor = palavras.some(
    (p) =>
      /[\p{L}\d]/u.test(p.text) &&
      (p.bbox.y0 + p.bbox.y1) / 2 > b.y1 &&
      p.bbox.x0 < left + width &&
      p.bbox.x1 > left &&
      p.bbox.y0 < top + height &&
      p.bbox.y1 > top &&
      (p.bbox.x0 < left ||
        p.bbox.x1 > left + width ||
        p.bbox.y0 < top ||
        p.bbox.y1 > top + height),
  );
  if (cortaValor) return null;
  return width > 0 && height > 0 ? { left, top, width, height } : null;
}

export function valorDoCampo(
  blocos: Block[] | null,
  campo: Exclude<CampoCnh, 'nome'>,
  largura: number,
  altura: number,
): string | null {
  const regiao = regiaoDoCampo(blocos, campo, largura, altura);
  if (!regiao) return null;
  const todas = linhas(blocos);
  const titulo = todas
    .flatMap((l) => l.words)
    .find((p) => padroes[campo].test(rotulo(p.text)))!;
  const h = titulo.bbox.y1 - titulo.bbox.y0;
  const dentro = (p: Word) =>
    p.bbox.x0 >= regiao.left &&
    p.bbox.x1 <= regiao.left + regiao.width &&
    p.bbox.y0 >= titulo.bbox.y1 - h / 2 &&
    (p.bbox.y0 + p.bbox.y1) / 2 > titulo.bbox.y1 &&
    p.bbox.y1 <= regiao.top + regiao.height;
  const candidatos = todas
    .map((l) =>
      l.words
        .filter(dentro)
        .sort((a, b) => a.bbox.x0 - b.bbox.x0)
        .map((p) => limparBorda(p.text))
        .filter(Boolean)
        .join(' '),
    )
    .filter(Boolean);
  if (candidatos.length !== 1) return null;
  return validarFormato(campo, candidatos[0]);
}

function validarFormato(campo: Exclude<CampoCnh, 'nome'>, valor: string) {
  const texto = normalizar(limparBorda(valor));
  const formato = {
    cpf: /^(?:\d[\d .-]*\d)$/,
    validade: /^\d{2}\s*([/.])\s*\d{2}\s*\1\s*\d{4}$/,
    categoria: /^(?:A?[BCDE]|A|ACC)$/,
  }[campo];
  return formato.test(texto) ? texto : null;
}

// Usado somente em um recorte delimitado por um título único já localizado.
export function valorDoRecorte(texto: string, campo: CampoCnh): string | null {
  const partes = texto.split(/\r?\n/).map(limparBorda).filter(Boolean);
  const titulos = partes
    .map((p, i) => ({ p: rotulo(p), i }))
    .filter(({ p }) =>
      campo === 'nome'
        ? /NOME/.test(p)
        : campo === 'categoria'
          ? /(?:CATEGORIA|CATHAB)/.test(p)
          : campo === 'cpf'
            ? /CPF/.test(p)
            : /VALIDADE/.test(p),
    );
  if (titulos.length !== 1) return null;
  const valores = partes.slice(titulos[0].i + 1);
  if (!valores.length || valores.length > (campo === 'nome' ? 2 : 1))
    return null;
  const valor = valores.join(' ');
  if (campo !== 'nome') return validarFormato(campo, valor);
  if (
    /\b(CPF|DATA|FILIACAO|NASCIMENTO|VALIDADE|HABILITACAO)\b/.test(
      normalizar(valor),
    )
  )
    return null;
  return /^[\p{L}]+(?:['’-][\p{L}]+)*(?:\s+[\p{L}]+(?:['’-][\p{L}]+)*)+$/u.test(
    valor,
  )
    ? valor
    : null;
}
