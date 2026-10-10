import type { Bbox, Block } from 'tesseract.js';

export interface LeituraCnh {
  texto: string;
  nome: string | null;
}

const normalizar = (texto: string) =>
  texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .trim();
const outroCampo =
  /\b(CPF|REGISTRO|VALIDADE|CATEGORIA|CAT|FILIACAO|NASCIMENTO|DATA|DOC|IDENTIDADE|ASSINATURA|NACIONALIDADE|PERMISSAO)\b/;
const sobrepoe = (a: Bbox, b: Bbox) => a.x0 < b.x1 && a.x1 > b.x0;

// Nunca usamos o nome digitado para escolher palavras da foto.
export function nomePeloLayout(blocos: Block[] | null): string | null {
  const linhas = (blocos ?? []).flatMap((b) =>
    b.paragraphs.flatMap((p) => p.lines),
  );
  const palavras = linhas.flatMap((l) => l.words);
  const titulos = palavras.filter((p) =>
    /^NOME[:.-]?$/.test(normalizar(p.text)),
  );
  if (titulos.length !== 1) return null;
  const titulo = titulos[0];
  const linhaTitulo = linhas.find((linha) => linha.words.includes(titulo))!;
  const prefixo = linhaTitulo.words.filter((p) => p.bbox.x1 <= titulo.bbox.x0);
  const inicio = /^[\d\sEe./-]*$/.test(prefixo.map((p) => p.text).join(' '))
    ? Math.min(titulo.bbox.x0, ...prefixo.map((p) => p.bbox.x0))
    : titulo.bbox.x0;
  const altura = titulo.bbox.y1 - titulo.bbox.y0;
  if (altura <= 0) return null;
  const vizinhos = palavras.filter(
    (p) =>
      p.bbox.x0 > titulo.bbox.x1 &&
      Math.abs(p.bbox.y0 - titulo.bbox.y0) < altura &&
      outroCampo.test(normalizar(p.text)),
  );
  const regiao: Bbox = {
    x0: inicio - altura,
    x1: Math.min(
      Math.max(...palavras.map((p) => p.bbox.x1)) + 1,
      ...vizinhos.map((p) => p.bbox.x0),
    ),
    y0: titulo.bbox.y1,
    y1: titulo.bbox.y1 + altura * 6,
  };
  const proximosCampos = palavras.filter(
    (p) =>
      p.bbox.y0 > regiao.y0 &&
      sobrepoe(p.bbox, regiao) &&
      outroCampo.test(normalizar(p.text)),
  );
  regiao.y1 = Math.min(regiao.y1, ...proximosCampos.map((p) => p.bbox.y0));
  // Não descartar silenciosamente uma palavra que cruza a borda:
  // isso poderia transformar um nome completo em outro nome mais curto.
  const cortada = palavras.some(
    (p) =>
      sobrepoe(p.bbox, regiao) &&
      p.bbox.y1 > regiao.y0 &&
      p.bbox.y0 < regiao.y1 &&
      (p.bbox.x0 < regiao.x0 ||
        p.bbox.x1 > regiao.x1 ||
        p.bbox.y0 < regiao.y0 ||
        p.bbox.y1 > regiao.y1),
  );
  if (cortada) return null;
  const candidatas = linhas
    .map((linha) =>
      linha.words
        .filter(
          (p) =>
            p.bbox.y0 >= regiao.y0 &&
            p.bbox.y1 <= regiao.y1 &&
            p.bbox.x0 >= regiao.x0 &&
            p.bbox.x1 <= regiao.x1,
        )
        .sort((a, b) => a.bbox.x0 - b.bbox.x0),
    )
    .filter((linha) => linha.length > 0)
    .sort((a, b) => a[0].bbox.y0 - b[0].bbox.y0);
  if (!candidatas.length || candidatas.length > 2) return null;
  if (candidatas[0][0].bbox.y0 - regiao.y0 > altura * 3) return null;
  const nome = candidatas
    .map((linha) => linha.map((p) => p.text).join(' '))
    .join(' ');
  if (
    outroCampo.test(normalizar(nome)) ||
    !/^[\p{L}]+(?:['’.-]?[\p{L}]+)*(?:\s+[\p{L}]+(?:['’.-]?[\p{L}]+)*)+$/u.test(
      nome,
    )
  )
    return null;
  return nome;
}
