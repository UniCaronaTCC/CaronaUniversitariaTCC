import type { Block } from 'tesseract.js';
import {
  regiaoDoCampo,
  valorDoCampo,
  valorDoRecorte,
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
