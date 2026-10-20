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
  it('lê o nome quando o ML Kit agrupa título e valor na mesma TextLine', () => {
    const unificada = linha('NOME E SOBRENOME', 100, 10);
    unificada.words.push(...linha('MARIA CLARA SILVA', 100, 40).words);
    expect(nomePeloLayout(blocos(unificada))).toBe('MARIA CLARA SILVA');
  });
  it('não encurta o nome ao agrupar título com palavra fora da região', () => {
    const unificada = linha('NOME E SOBRENOME', 100, 10);
    unificada.words.push(...linha('MARIA CLARA SILVA', 60, 40).words);
    expect(nomePeloLayout(blocos(unificada))).toBeNull();
  });
  it('preserva palavra com caixa ampliada por moldura quando a linha de base confirma o nome', () => {
    const nome = linha('MARIA CLARA SILVA', 100, 24);
    for (const p of nome.words) p.bbox.y1 = 40;
    nome.words[0].bbox.y0 = 12;
    nome.words[0].bbox.y1 = 41;
    const titulo = linha('NOME', 100, 10);
    titulo.words[0].bbox.y1 = 20;
    expect(nomePeloLayout(blocos(titulo, nome))).toBe('MARIA CLARA SILVA');
  });
  it('isola data de coluna vizinha com cabeçalho ligeiramente mais alto', () => {
    const titulo = linha('NOME', 100, 20);
    const vizinho = linha('HABILITACAO', 600, 10);
    const nome = linha('MARIA CLARA SILVA', 100, 40);
    nome.words.push(...linha('01/01/2020', 600, 28).words);
    expect(nomePeloLayout(blocos(titulo, vizinho, nome))).toBe(
      'MARIA CLARA SILVA',
    );
  });
  it('ignora cabeçalho acima do nome que toca a borda vertical', () => {
    const cabecalho = linha('NOME E SOBRENOME', 100, 10);
    cabecalho.words[2].bbox.y0 = 13;
    cabecalho.words[2].bbox.y1 = 28;
    const vizinho = linha('1 HABILITACAO', 600, 14);
    expect(
      nomePeloLayout(blocos(cabecalho, vizinho, linha('MARIA SILVA', 100, 35))),
    ).toBe('MARIA SILVA');
  });
  it('preserva sobrenome com pequena sobreposição vertical ao título', () => {
    const nome = linha('JOAO PEDRO SILVA', 100, 28);
    nome.words[2].bbox.y0 = 22;
    expect(nomePeloLayout(blocos(linha('NOME', 100, 10), nome))).toBe(
      'JOAO PEDRO SILVA',
    );
  });
  it('recusa sobreposição excessiva em vez de omitir parte do nome', () => {
    const nome = linha('JOAO PEDRO SILVA', 100, 28);
    nome.words[2].bbox.y0 = 12;
    expect(nomePeloLayout(blocos(linha('NOME', 100, 10), nome))).toBeNull();
  });
  it.each([
    ['TITULO_AUSENTE', null],
    [
      'TITULO_DUPLICADO',
      blocos(linha('NOME', 100, 10), linha('NOME', 100, 80)),
    ],
    ['REGIAO_VAZIA', blocos(linha('NOME', 100, 10))],
    [
      'PALAVRA_NA_BORDA',
      blocos(linha('NOME', 100, 10), linha('JOAO PEDRO SILVA', 60, 40)),
    ],
    [
      'EXCESSO_DE_LINHAS',
      blocos(
        linha('NOME', 100, 10),
        linha('JOAO', 100, 30),
        linha('PEDRO', 100, 50),
        linha('SILVA', 100, 70),
      ),
    ],
    [
      'NOME_DISTANTE',
      blocos(linha('NOME', 100, 10), linha('JOAO PEDRO', 100, 80)),
    ],
    [
      'FORMATO_INVALIDO',
      blocos(linha('NOME', 100, 10), linha('JOAO 123', 100, 40)),
    ],
    [
      'REGIAO_LIDA',
      blocos(linha('NOME', 100, 10), linha('JOAO PEDRO', 100, 40)),
    ],
  ] as const)(
    'diagnostica %s sem expor texto ou alterar o resultado',
    (motivo, entrada) => {
      const diagnosticar = jest.fn();
      expect(nomePeloLayout(entrada, diagnosticar)).toBe(
        nomePeloLayout(entrada),
      );
      expect(diagnosticar).toHaveBeenCalledTimes(1);
      expect(diagnosticar).toHaveBeenCalledWith({
        motivo,
        titulos: expect.any(Number) as number,
        linhasCandidatas: expect.any(Number) as number,
      });
      expect(JSON.stringify(diagnosticar.mock.calls)).not.toMatch(
        /JOAO|PEDRO|SILVA|123|bbox/,
      );
    },
  );
  it('aceita pontuação depois do título', () => {
    expect(
      nomePeloLayout(
        blocos(
          linha('NOME:', 100, 10),
          linha('JOAO PEDRO', 100, 40),
          linha('CPF', 100, 80),
        ),
      ),
    ).toBe('JOAO PEDRO');
  });
  it('não devolve nome parcial quando uma palavra cruza o limite esquerdo', () => {
    expect(
      nomePeloLayout(
        blocos(
          linha('NOME', 100, 10),
          linha('JOAO PEDRO SILVA', 60, 40),
          linha('CPF', 100, 80),
        ),
      ),
    ).toBeNull();
  });
  it('não devolve nome parcial quando uma palavra cruza o limite inferior', () => {
    const nome = linha('JOAO PEDRO SILVA', 100, 40);
    nome.words[2].bbox.y1 = 82;
    expect(
      nomePeloLayout(
        blocos(linha('NOME', 100, 10), nome, linha('CPF', 100, 80)),
      ),
    ).toBeNull();
  });
  it('isola o nome abaixo de título numerado e bilíngue', () => {
    const resultado = nomePeloLayout(
      blocos(
        linha('2 E 1 NOME E SOBRENOME / NAME AND SURNAME', 100, 10),
        linha('JOAO PEDRO DA SILVA', 100, 40),
        linha('CPF', 100, 75),
        linha('MARIA SILVA', 100, 100),
      ),
    );
    expect(resultado).toBe('JOAO PEDRO DA SILVA');
  });
  it('exclui coluna vizinha mesmo quando o OCR mistura a linha', () => {
    const titulo = linha('NOME', 100, 10);
    titulo.words.push(...linha('CPF', 600, 10).words);
    const nome = linha('JOAO PEDRO DA SILVA', 100, 40);
    nome.words.push(...linha('529.982.247-25', 600, 40).words);
    expect(
      nomePeloLayout(blocos(titulo, nome, linha('VALIDADE', 100, 80))),
    ).toBe('JOAO PEDRO DA SILVA');
  });
  it('junta duas linhas do nome na mesma região', () => {
    expect(
      nomePeloLayout(
        blocos(
          linha('NOME', 100, 10),
          linha('JOAO PEDRO', 100, 35),
          linha('DA SILVA', 100, 60),
          linha('CPF', 100, 90),
        ),
      ),
    ).toBe('JOAO PEDRO DA SILVA');
  });
  it('não depende da ordem dos blocos', () => {
    expect(
      nomePeloLayout(
        blocos(
          linha('CPF', 100, 90),
          linha('JOAO PEDRO', 100, 40),
          linha('NOME', 100, 10),
        ),
      ),
    ).toBe('JOAO PEDRO');
  });
  it.each([
    null,
    blocos(linha('JOAO PEDRO', 100, 40)),
    blocos(linha('NOME', 100, 10), linha('NOME', 100, 90)),
    blocos(linha('NOME', 100, 10), linha('JOAO 123', 100, 40)),
    blocos(linha('NOME', 100, 10), linha('JOAO PEDRO', 100, 200)),
  ])('recusa região ausente, distante ou ambígua %#', (entrada) => {
    expect(nomePeloLayout(entrada)).toBeNull();
  });

  const texto =
    'NOME ERRADO\nCPF 529.982.247-25\nCATEGORIA B\nVALIDADE 06/10/2099\nREGISTRO 12345678901';
  it('usa somente o nome localizado e mantém a comparação integral', () => {
    const entrada = {
      texto,
      nome: 'JOAO PEDRO DA SILVA',
      campos: { cpf: '529.982.247-25', categoria: 'B', validade: '06/10/2099' },
    };
    expect(
      conferirDadosCnh(entrada, 'João Pedro da Silva', '2026-10-09').dados,
    ).not.toBeNull();
    expect(conferirDadosCnh(entrada, 'João Pedro', '2026-10-09').motivo).toBe(
      'NOME_DIVERGENTE',
    );
  });
  it('não volta ao texto inteiro quando a região não foi encontrada', () => {
    expect(
      conferirDadosCnh({ texto, nome: null }, 'Nome Errado', '2026-10-09')
        .motivo,
    ).toBe('NOME_NAO_LIDO');
  });
});
