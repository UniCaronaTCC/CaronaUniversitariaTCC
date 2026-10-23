import { nomePeloLayout } from './nome-cnh-layout';
import type { Block, Word } from './ocr-cnh';

const palavra = (
  text: string,
  x0: number,
  y0: number,
  x1: number,
  y1: number,
): Word => ({ text, bbox: { x0, y0, x1, y1 } });
const blocos = (...linhas: Word[][]): Block[] => [
  { paragraphs: [{ lines: linhas.map((words) => ({ words })) }] },
];

describe('geometria do cabeçalho do nome', () => {
  const entrada = (prefixo: string, y = 269) =>
    blocos(
      [palavra('HABILITACAO', 649, 240, 774, 276)],
      [
        palavra(prefixo, 416, y, 465, y + 22),
        palavra('NOME', 482, 268, 532, 290),
        palavra('E', 542, 268, 546, 289),
        palavra('SOBRENOME', 549, 266, 658, 289),
      ],
      [palavra('THABILTACAO', 1087, 267, 1203, 284)],
      [palavra('01/01/2020', 1102, 281, 1205, 308)],
      [
        palavra('MARIA', 436, 289, 561, 316),
        palavra('CLARA', 568, 288, 670, 315),
        palavra('SILVA', 677, 288, 770, 313),
      ],
      [palavra('DATA', 743, 326, 778, 345)],
    );

  it.each(['(261', '261', '[261]', '2e1'])(
    'ignora o título geral sobreposto e usa prefixo numérico %s do cabeçalho',
    (prefixo) =>
      expect(nomePeloLayout(entrada(prefixo))).toBe('MARIA CLARA SILVA'),
  );

  it('preserva a linha inteira mesmo sem numeração alinhada', () => {
    expect(nomePeloLayout(entrada('(261', 180))).toBe('MARIA CLARA SILVA');
  });

  it('não precisa usar texto arbitrário do cabeçalho para extrair a linha', () => {
    expect(nomePeloLayout(entrada('ABC'))).toBe('MARIA CLARA SILVA');
  });
});
