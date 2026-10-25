import type { Bbox, Block } from './ocr-cnh';
import type { CamposCnh } from './campos-cnh-layout';

export interface LeituraCnh {
  texto: string;
  nome: string | null;
  registro?: string | null;
  campos?: CamposCnh;
  diagnosticoNome?: DiagnosticoRegiaoNome;
}

const normalizar = (texto: string) =>
  texto
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .trim();
const outroCampo =
  /\b(CPF|REGISTRO|VALIDADE|CATEGORIA|CAT|FILIACAO|NASCIMENTO|DATA|DOC|IDENTIDADE|ASSINATURA|NACIONALIDADE|PERMISSAO|HABILITACAO)\b/;
const sobrepoe = (a: Bbox, b: Bbox) => a.x0 < b.x1 && a.x1 > b.x0;
// Uma moldura pode virar um caractere unido à numeração impressa "2 e 1".
// A tolerância vale apenas para esse prefixo, nunca para o nome da pessoa.
const normalizarPrefixo = (texto: string) =>
  normalizar(texto)
    .replace(/^[|()[\]{}]+|[|()[\]{}]+$/g, '')
    .replace(/^[^\d](?=2\s*E\s*1$)/, '');

type MotivoRegiao =
  | 'TITULO_AUSENTE'
  | 'TITULO_DUPLICADO'
  | 'ALTURA_INVALIDA'
  | 'REGIAO_VAZIA'
  | 'REGIAO_LIDA';

export interface DiagnosticoRegiaoNome {
  motivo: MotivoRegiao;
  titulos: number;
  linhasCandidatas: number;
}

// Nunca usamos o nome digitado para escolher palavras da foto.
export function nomePeloLayout(
  blocos: Block[] | null,
  diagnosticar?: (diagnostico: DiagnosticoRegiaoNome) => void,
): string | null {
  const linhas = (blocos ?? []).flatMap((b) =>
    b.paragraphs.flatMap((p) => p.lines),
  );
  const palavras = linhas.flatMap((l) => l.words);
  const titulos = palavras.filter((p) =>
    /^NOME[:.-]?$/.test(normalizar(p.text)),
  );
  let linhasCandidatas = 0;
  const concluir = (motivo: MotivoRegiao, nome: string | null = null) => {
    diagnosticar?.({ motivo, titulos: titulos.length, linhasCandidatas });
    return nome;
  };
  if (!titulos.length) return concluir('TITULO_AUSENTE');
  if (titulos.length > 1) return concluir('TITULO_DUPLICADO');
  const titulo = titulos[0];
  const linhaTitulo = linhas.find((linha) => linha.words.includes(titulo))!;
  const altura = titulo.bbox.y1 - titulo.bbox.y0;
  if (altura <= 0) return concluir('ALTURA_INVALIDA');
  // A numeração "2 e 1" pode vir em outro bloco do ML Kit. Ela faz
  // parte do cabeçalho da mesma célula, mesmo sem compartilhar TextLine.
  const prefixo: (typeof palavras)[number][] = [];
  let esquerda = titulo.bbox.x0;
  const anteriores = palavras
    .filter(
      (p) =>
        p !== titulo &&
        p.bbox.x1 <= titulo.bbox.x0 &&
        Math.abs(
          (p.bbox.y0 + p.bbox.y1 - titulo.bbox.y0 - titulo.bbox.y1) / 2,
        ) <=
          altura / 2,
    )
    .sort((a, b) => b.bbox.x1 - a.bbox.x1);
  for (const p of anteriores) {
    if (
      prefixo.length === 3 ||
      esquerda - p.bbox.x1 > altura * 2 ||
      !/^(?:\d{1,3}|E|\d{1,2}\s*E\s*\d{1,2})$/.test(normalizarPrefixo(p.text))
    )
      break;
    prefixo.unshift(p);
    esquerda = p.bbox.x0;
  }
  if (
    !/^\d{1,3}(?:\s*E\s*\d{1,2})?$/.test(
      prefixo.map((p) => normalizarPrefixo(p.text)).join(' '),
    )
  )
    prefixo.length = 0;
  const inicio = Math.min(titulo.bbox.x0, ...prefixo.map((p) => p.bbox.x0));
  // O ML Kit pode agrupar título e valor em uma só TextLine. Excluir
  // a linha inteira descartaria também o nome, mesmo estando abaixo.
  const palavrasTitulo = new Set([
    titulo,
    ...prefixo,
    ...linhaTitulo.words.filter(
      (p) =>
        p.bbox.x0 >= titulo.bbox.x1 &&
        p.bbox.y0 <= titulo.bbox.y1 &&
        /^(?:E|SOBRENOME|\/|NAME|AND|SURNAME)$/.test(normalizar(p.text)),
    ),
  ]);
  const vizinhos = palavras.filter(
    (p) =>
      p.bbox.x0 > titulo.bbox.x1 &&
      p.bbox.y0 < titulo.bbox.y1 &&
      p.bbox.y1 > titulo.bbox.y0 &&
      // Caixas de letras altas do título geral podem sobrepor NOME.
      // Um campo da mesma linha também precisa ter o centro alinhado.
      Math.abs((p.bbox.y0 + p.bbox.y1 - titulo.bbox.y0 - titulo.bbox.y1) / 2) <=
        altura * 0.75 &&
      (outroCampo.test(normalizar(p.text)) ||
        /^(?:1[ªAº°.]?|T)\s*HABILI?TACAO$/.test(normalizar(p.text))),
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
  // A região escolhe linhas prováveis, sem cortar palavras nas margens.
  const candidatas = linhas
    .map((linha) => {
      const valores = linha.words.filter(
        (p) =>
          !palavrasTitulo.has(p) &&
          !outroCampo.test(normalizar(p.text)) &&
          /[\p{L}\d]/u.test(p.text) &&
          (p.bbox.y0 + p.bbox.y1) / 2 > regiao.y0 &&
          p.bbox.y0 < regiao.y1 &&
          !(vizinhos.length && (p.bbox.x0 + p.bbox.x1) / 2 >= regiao.x1),
      );
      return valores.some((p) => sobrepoe(p.bbox, regiao))
        ? valores.sort((a, b) => a.bbox.x0 - b.bbox.x0)
        : [];
    })
    .filter((linha) => linha.length > 0)
    .sort((a, b) => a[0].bbox.y0 - b[0].bbox.y0);
  linhasCandidatas = candidatas.length;
  if (!candidatas.length) return concluir('REGIAO_VAZIA');
  const nome = candidatas
    .map((linha) => linha.map((p) => p.text).join(' '))
    .join(' ');
  return concluir('REGIAO_LIDA', nome);
}
