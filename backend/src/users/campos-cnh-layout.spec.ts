import type { Block } from 'tesseract.js';
import {
  regiaoDoCampo,
  valorDoCampo,
  valorDoRecorte,
  rotulosCnhLocalizados,
} from './campos-cnh-layout';
import { conferirDadosCnh } from './dados-cnh';

const palavra = (text: string, x: number, y: number, width = 50) => ({
  text,
  bbox: { x0: x, x1: x + width, y0: y, y1: y + 10 },
});
const blocos = (...words: ReturnType<typeof palavra>[][]) =>
  [
    { paragraphs: [{ lines: words.map((w) => ({ words: w })) }] },
  ] as unknown as Block[];

describe('campos por posição', () => {
  it('aceita categoria completa deslocada para a esquerda do rótulo', () => {
    const entrada = blocos(
      [palavra('9 CAT.HAB.', 100, 10, 70)],
      [palavra('AB', 80, 30, 20)],
    );
    expect(valorDoCampo(entrada, 'categoria', 500, 200)).toBe('AB');
  });
  it('não usa categoria que cruza o limite da coluna anterior', () => {
    const entrada = blocos(
      [palavra('REGISTRO', 20, 10, 50), palavra('CAT.HAB.', 100, 10, 70)],
      [palavra('AB', 65, 30, 30)],
    );
    expect(regiaoDoCampo(entrada, 'categoria', 500, 200)).toBeNull();
  });
  it('exige rótulos únicos e nome para reconhecer orientação', () => {
    expect(rotulosCnhLocalizados(null)).toBe(false);
    expect(rotulosCnhLocalizados(blocos([palavra('NOME', 10, 10)]))).toBe(
      false,
    );
    expect(
      rotulosCnhLocalizados(
        blocos([
          palavra('NOME', 10, 10),
          palavra('CPF', 100, 10),
          palavra('VALIDADE', 200, 10),
        ]),
      ),
    ).toBe(true);
    expect(
      rotulosCnhLocalizados(
        blocos([
          palavra('NOME', 10, 10),
          palavra('NOME', 10, 40),
          palavra('CPF', 100, 10),
          palavra('VALIDADE', 200, 10),
        ]),
      ),
    ).toBe(false);
    const vertical = blocos([
      palavra('NOME', 10, 10),
      palavra('CPF', 100, 10),
      palavra('VALIDADE', 200, 10),
    ]);
    for (const p of vertical[0].paragraphs[0].lines[0].words) {
      p.bbox.x1 = p.bbox.x0 + 10;
      p.bbox.y1 = p.bbox.y0 + 50;
    }
    expect(rotulosCnhLocalizados(vertical)).toBe(false);
  });
  it('usa a célula inteira na releitura sem cortar dígitos omitidos na primeira leitura', () => {
    const entrada = blocos(
      [palavra('CPF', 100, 10, 25)],
      [palavra('982.247-25', 140, 30, 80)],
    );
    const r = regiaoDoCampo(entrada, 'cpf', 600, 200, true)!;
    expect(r.left).toBeLessThan(100);
    expect(r.left + r.width).toBeGreaterThan(220);
  });
  it('respeita borda vertical antes da coluna de registro', () => {
    const entrada = blocos(
      [palavra('CPF', 100, 10, 25)],
      [
        palavra('52998224725', 100, 30, 120),
        palavra('12345678901', 250, 30, 110),
      ],
      [{ text: ')(', bbox: { x0: 230, x1: 240, y0: 10, y1: 60 } }],
    );
    const r = regiaoDoCampo(entrada, 'cpf', 600, 200, true)!;
    expect(r.left + r.width).toBeLessThan(230);
  });
  it.each([
    ['4d CPF 529.982.247-25', 'cpf', '529.982.247-25'],
    ['4b VALIDADE 01/01/2030', 'validade', '01/01/2030'],
    ['9 CAT.HAB. AB', 'categoria', 'AB'],
    ['2 E 1 NOME E SOBRENOME MARIA SILVA', 'nome', 'MARIA SILVA'],
  ] as const)(
    'aceita rótulo e valor na mesma linha: %s',
    (texto, campo, esperado) => {
      expect(valorDoRecorte(texto, campo)).toBe(esperado);
    },
  );
  it.each([
    ['MARIA SILVA', 'nome', 'MARIA SILVA'],
    ['529.982.247-25', 'cpf', '529.982.247-25'],
    ['01/01/2030', 'validade', '01/01/2030'],
    ['AB', 'categoria', 'AB'],
  ] as const)(
    'usa valor sem repetir rótulo só em região confirmada: %s',
    (texto, campo, esperado) => {
      expect(valorDoRecorte(texto, campo)).toBeNull();
      expect(valorDoRecorte(texto, campo, true)).toBe(esperado);
    },
  );
  it.each([
    ['MARIA SILVA\nFILIACAO', 'nome'],
    ['MARIA SILVA\nOUTRO NOME\nMAIS UMA LINHA', 'nome'],
    ['NOME\nMARIA SILVA\nNOME\nOUTRA PESSOA', 'nome'],
    ['01/01/2030\n01/01/2020', 'validade'],
    ['AB\nA', 'categoria'],
    ['CPF\n529.982.247-25\nREGISTRO', 'cpf'],
  ] as const)(
    'não aceita campo ambíguo mesmo com rótulo confirmado: %s',
    (texto, campo) => {
      expect(valorDoRecorte(texto, campo, true)).toBeNull();
    },
  );
  it('separa CPF e registro que compartilham a mesma linha', () => {
    const entrada = blocos(
      [palavra('CPF', 100, 10, 25), palavra('REGISTRO', 300, 10)],
      [
        palavra('529.982.247-25', 100, 30, 120),
        palavra('12345678901', 300, 30, 120),
      ],
    );
    expect(valorDoCampo(entrada, 'cpf', 600, 200)).toBe('529.982.247-25');
  });
  it('não escolhe a data de emissão ao lado da validade', () => {
    const entrada = blocos(
      [palavra('EMISSAO', 20, 10), palavra('VALIDADE', 200, 10, 70)],
      [palavra('01/01/2020', 20, 30, 90), palavra('01/01/2030', 200, 30, 90)],
    );
    expect(valorDoCampo(entrada, 'validade', 500, 200)).toBe('01/01/2030');
  });
  it('não aprova rótulos duplicados ou valor cortado', () => {
    expect(
      regiaoDoCampo(
        blocos([palavra('CPF', 100, 10), palavra('CPF', 300, 10)]),
        'cpf',
        600,
        200,
      ),
    ).toBeNull();
    expect(
      regiaoDoCampo(
        blocos(
          [palavra('CPF', 100, 10)],
          [palavra('529.982.247-25', 60, 30, 150)],
        ),
        'cpf',
        600,
        200,
      ),
    ).toBeNull();
  });
  it('tolera rótulo de categoria imperfeito apenas para localizar o recorte', () => {
    expect(
      regiaoDoCampo(
        blocos([palavra('SCAT-.MAB', 100, 10)]),
        'categoria',
        500,
        200,
      ),
    ).not.toBeNull();
    expect(valorDoRecorte('SCAT-.MAB\nAB', 'categoria')).toBeNull();
    expect(valorDoRecorte('9 CAT.HAB.\nAB', 'categoria')).toBe('AB');
  });
  it.each([
    ['VALIDADE\n01/01/2030\n01/01/2020', 'validade'],
    ['CPF\n529982247251', 'cpf'],
    ['NOME\nMARIA SILVA\nFILIACAO', 'nome'],
  ] as const)(
    'recorte não inventa nem escolhe entre valores: %s',
    (texto, campo) => {
      const valor = valorDoRecorte(texto, campo);
      if (campo === 'cpf') {
        expect(
          conferirDadosCnh(
            {
              texto: '',
              nome: 'MARIA SILVA',
              campos: {
                cpf: valor,
                validade: '01/01/2030',
                categoria: 'B',
              },
            },
            'MARIA SILVA',
            '2026-10-11',
          ).motivo,
        ).toBe('CPF_INVALIDO');
      } else expect(valor).toBeNull();
    },
  );
  it('campo ausente não recorre ao texto de outra região', () => {
    expect(
      conferirDadosCnh(
        {
          nome: 'MARIA SILVA',
          texto: 'CPF 529.982.247-25',
          campos: { cpf: null, validade: '01/01/2030', categoria: 'B' },
        },
        'MARIA SILVA',
        '2026-10-11',
      ).motivo,
    ).toBe('CPF_NAO_LIDO');
  });
});
