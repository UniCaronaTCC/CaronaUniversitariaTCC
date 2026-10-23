import type { Block, Word } from './ocr-cnh';
import type { RelatarCampoCnh, MotivoCampoCnh } from './diagnostico-campo-cnh';

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
  /^(?:NOME|CPF|N?REGISTRO|VALIDADE|CAT|CATHAB|HAB|CATEGORIA|[A-E]?DATA|NASCIMENTO|[A-E]?FILIACAO|[A-E]?NACIONALIDADE|[A-E]?(?:DOC(?:IDENTIDADE)?|IDENTIDADE)(?:ORGEMISSORUF)?|ORG|EMISSOR|UF|ACC|HABILITACAO)$/;
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
  relatar?: RelatarCampoCnh,
): RegiaoCnh | null {
  const recusar = (motivo: MotivoCampoCnh) => {
    relatar?.(motivo);
    return null;
  };
  const palavras = linhas(blocos).flatMap((l) => l.words);
  const titulos = palavras.filter((p) => padroes[campo].test(rotulo(p.text)));
  if (!titulos.length) return recusar('TITULO_AUSENTE');
  if (titulos.length > 1) return recusar('TITULO_DUPLICADO');
  const titulo = titulos[0];
  const b = titulo.bbox;
  if (b.y1 <= b.y0) return recusar('ALTURA_INVALIDA');
  const alturas = palavras
    .filter((p) =>
      Object.values(padroes).some((padrao) => padrao.test(rotulo(p.text))),
    )
    .map((p) => p.bbox.y1 - p.bbox.y0)
    .filter((h) => h > 0)
    .sort((a, b) => a - b);
  const h =
    campo === 'validade'
      ? Math.max(b.y1 - b.y0, alturas[Math.floor(alturas.length / 2)] ?? 0)
      : b.y1 - b.y0;
  if (h <= 0) return recusar('ALTURA_INVALIDA');
  const vizinhos = palavras.filter(
    (p) =>
      p !== titulo &&
      p.bbox.x0 > b.x1 &&
      Math.abs(p.bbox.y0 - b.y0) < h &&
      outro.test(rotulo(p.text)) &&
      !(campo === 'categoria' && rotulo(p.text) === 'HAB'),
  );
  const anteriores =
    campo === 'categoria'
      ? palavras.filter(
          (p) =>
            p.bbox.x1 < b.x0 &&
            Math.abs(p.bbox.y0 - b.y0) < h &&
            outro.test(rotulo(p.text)),
        )
      : [];
  let left = Math.max(
    0,
    Math.floor(b.x0 - h * (campo === 'nome' || campo === 'categoria' ? 4 : 3)),
    ...anteriores.map((p) =>
      Math.ceil((p.bbox.x0 + p.bbox.x1 + b.x0 + b.x1) / 4),
    ),
  );
  let right = Math.min(
    largura,
    b.x1 +
      h *
        (campo === 'nome'
          ? 40
          : campo === 'cpf'
            ? 14
            : campo === 'validade'
              ? 8
              : 3),
    ...vizinhos.map((p) => p.bbox.x0 - h * 2),
  );
  // Linhas verticais reconhecidas como pontuação delimitam a célula,
  // inclusive quando o OCR não conseguiu ler o rótulo da coluna vizinha.
  const bordas = palavras.filter(
    (p) =>
      /^[|()[\]{}]+$/.test(p.text.trim()) &&
      p.bbox.y0 <= b.y1 &&
      p.bbox.y1 > b.y1 + h &&
      p.bbox.y1 - p.bbox.y0 >= h * 2,
  );
  left = Math.max(
    left,
    ...bordas
      .filter((p) => p.bbox.x1 < b.x0 && p.bbox.x1 >= left)
      .map((p) => p.bbox.x1 + 1),
  );
  right = Math.min(
    right,
    ...bordas
      .filter((p) => p.bbox.x0 > b.x1 && p.bbox.x0 <= right)
      .map((p) => p.bbox.x0 - 1),
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
    b.y1 + h * 6,
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
      !outro.test(rotulo(p.text)) &&
      // O registro também tem onze dígitos. A posição sob um rótulo vizinho,
      // e não o formato numérico, distingue essa coluna do CPF.
      !(
        campo !== 'nome' &&
        vizinhos.some((v) => (p.bbox.x0 + p.bbox.x1) / 2 >= v.bbox.x0)
      ) &&
      !(
        campo !== 'nome' &&
        ((p.bbox.x0 + p.bbox.x1) / 2 < left ||
          (p.bbox.x0 + p.bbox.x1) / 2 > right) &&
        !validarFormato(campo, p.text)
      ) &&
      (campo === 'nome' ||
        validarFormato(campo, p.text) ||
        /\d/.test(p.text)) &&
      (p.bbox.x0 < left ||
        p.bbox.x1 > left + width ||
        p.bbox.y0 < top ||
        p.bbox.y1 > top + height),
  );
  if (cortaValor) return recusar('PALAVRA_NA_BORDA');
  if (width <= 0 || height <= 0) return recusar('REGIAO_VAZIA');
  relatar?.('REGIAO_LOCALIZADA');
  return { left, top, width, height };
}

export function valorDoCampo(
  blocos: Block[] | null,
  campo: Exclude<CampoCnh, 'nome'>,
  largura: number,
  altura: number,
  relatar?: RelatarCampoCnh,
): string | null {
  const regiao = regiaoDoCampo(blocos, campo, largura, altura, relatar);
  if (!regiao) return null;
  const todas = linhas(blocos);
  const titulo = todas
    .flatMap((l) => l.words)
    .find((p) => padroes[campo].test(rotulo(p.text)))!;
  const dentro = (p: Word) =>
    p.bbox.x0 >= regiao.left &&
    p.bbox.x1 <= regiao.left + regiao.width &&
    p.bbox.y0 >= regiao.top &&
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
  if (candidatos.length !== 1) {
    relatar?.(candidatos.length ? 'VALOR_AMBIGUO' : 'VALOR_AUSENTE');
    return null;
  }
  const valor = validarFormato(campo, candidatos[0]);
  relatar?.(valor ? 'CAMPO_LIDO' : 'FORMATO_INVALIDO');
  return valor;
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
