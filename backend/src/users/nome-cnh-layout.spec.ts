import type { Block } from './ocr-cnh';
import { nomePeloLayout } from './nome-cnh-layout';
import { conferirDadosCnh } from './dados-cnh';

function linha(texto: string, x: number, y: number) {
  return {
    words: texto.split(' ').map((text, i) => ({
      text,
      bbox: { x0: x + i * 70, x1: x + i * 70 + 60, y0: y, y1: y + 15 },
    })),
  };
}
function blocos(...lines: ReturnType<typeof linha>[]): Block[] {
  return [{ paragraphs: [{ lines }] }];
}

describe('nomePeloLayout', () => {
  it('separa primeira habilitação quando o OCR lê a numeração como T', () => {
    const titulo = linha('NOME', 226, 681);
    titulo.words[0].bbox = { x0: 226, y0: 681, x1: 266, y1: 695 };
    const vizinho = linha('THABILITAÇÃO', 730, 673);
    vizinho.words[0].bbox = { x0: 730, y0: 673, x1: 822, y1: 690 };
    const data = linha('01/01/2020', 734, 686);
    data.words[0].bbox = { x0: 734, y0: 686, x1: 822, y1: 710 };
    expect(
      nomePeloLayout(
        blocos(
          titulo,
          vizinho,
          data,
          linha('MARIA CLARA SILVA', 226, 700),
          linha('NASCIMENTO', 400, 726),
        ),
      ),
    ).toBe('MARIA CLARA SILVA');
  });
  it('não usa o título geral acima como borda e aceita moldura junto à numeração', () => {
    const palavra = (
      text: string,
      x0: number,
      y0: number,
      x1: number,
      y1: number,
    ) => ({ text, bbox: { x0, y0, x1, y1 } });
    const entrada: Block[] = [
      {
        paragraphs: [
          {
            lines: [
              { words: [palavra('HABILITACAO', 484, 262, 562, 283)] },
              { words: [palavra('1HABILTACAO', 758, 283, 834, 297)] },
              { words: [palavra('01/01/2020', 768, 300, 834, 313)] },
              {
                words: [
                  palavra('r2e1', 353, 287, 381, 301),
                  palavra('NOME', 389, 287, 419, 300),
                  palavra('E', 431, 286, 433, 299),
                  palavra('SOBRENOME', 439, 286, 500, 300),
                ],
              },
              {
                words: [
                  palavra('MARIA', 365, 302, 431, 317),
                  palavra('CLARA', 435, 301, 473, 316),
                  palavra('SILVA', 478, 301, 535, 316),
                ],
              },
            ],
          },
        ],
      },
    ];
    expect(nomePeloLayout(entrada)).toBe('MARIA CLARA SILVA');
  });
  it('preserva o nome inteiro ao ultrapassar as margens estimadas', () => {
    const nome = linha('JOAO PEDRO SILVA', 60, 40);
    nome.words[2].bbox.y1 = 82;
    expect(
      nomePeloLayout(
        blocos(linha('NOME', 100, 10), nome, linha('CPF', 100, 80)),
      ),
    ).toBe('JOAO PEDRO SILVA');
  });
  it('mantém caracteres do OCR sem corrigir pelo nome do perfil', () => {
    expect(
      nomePeloLayout(
        blocos(linha('NOME', 100, 10), linha('JOA0 SILVA', 100, 40)),
      ),
    ).toBe('JOA0 SILVA');
  });
  it('lê título e valor agrupados na mesma linha do ML Kit', () => {
    const unificada = linha('NOME E SOBRENOME', 100, 10);
    unificada.words.push(...linha('MARIA CLARA SILVA', 60, 40).words);
    expect(nomePeloLayout(blocos(unificada))).toBe('MARIA CLARA SILVA');
  });
  it('não inclui dados da coluna vizinha no nome', () => {
    const nome = linha('MARIA SILVA', 100, 40);
    nome.words.push(...linha('01/01/2020', 600, 40).words);
    expect(
      nomePeloLayout(
        blocos(linha('NOME', 100, 10), linha('HABILITACAO', 600, 10), nome),
      ),
    ).toBe('MARIA SILVA');
  });
  it.each([
    null,
    blocos(linha('JOAO PEDRO', 100, 40)),
    blocos(linha('NOME', 100, 10), linha('NOME', 100, 80)),
  ])('não inventa nome sem título inequívoco %#', (entrada) =>
    expect(nomePeloLayout(entrada)).toBeNull(),
  );
  it('exige nome extraído sem reintroduzir comparação com o perfil', () => {
    expect(
      conferirDadosCnh(
        {
          texto: '',
          nome: null,
          campos: {
            cpf: '529.982.247-25',
            categoria: 'B',
            validade: '06/10/2099',
          },
        },
        '2026-10-23',
      ).motivo,
    ).toBe('NOME_NAO_LIDO');
  });
});
