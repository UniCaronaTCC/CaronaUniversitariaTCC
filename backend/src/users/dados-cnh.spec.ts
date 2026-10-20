import { conferirDadosCnh, cpfValido, nomeCompletoValido } from './dados-cnh';
import type { LeituraCnh } from './nome-cnh-layout';

describe('conferência dos campos extraídos do ML Kit', () => {
  const leitura = (): LeituraCnh => ({
    texto: '',
    nome: 'JOÃO PEDRO DA SILVA',
    campos: { cpf: '529.982.247-25', categoria: 'AB', validade: '06/10/2030' },
  });
  const conferir = (l: LeituraCnh) =>
    conferirDadosCnh(l, 'João Pedro da Silva', '2026-10-20');
  it('persiste apenas campos necessários e normaliza nome', () => {
    expect(
      conferirDadosCnh(leitura(), '  joão   PEDRO da Silva ', '2026-10-20')
        .dados,
    ).toEqual({ cpf: '52998224725', categoria: 'AB', validade: '2030-10-06' });
  });
  it.each([
    'João',
    'João Pedro',
    'Pedro da Silva',
    'João Pedro da Silva Junior',
  ])('recusa nome incompleto/divergente: %s', (nome) => {
    expect(conferirDadosCnh(leitura(), nome, '2026-10-20').motivo).toBe(
      'NOME_DIVERGENTE',
    );
  });
  it.each([
    ['cpf', null, 'CPF_NAO_LIDO'],
    ['cpf', '11111111111', 'CPF_INVALIDO'],
    ['cpf', '529982247251', 'CPF_INVALIDO'],
    ['cpf', 'REGISTRO 52998224725', 'CPF_INVALIDO'],
    ['validade', null, 'VALIDADE_NAO_LIDA'],
    ['validade', '31/02/2030', 'VALIDADE_NAO_LIDA'],
    ['validade', '06/10/2030 07/10/2030', 'VALIDADE_NAO_LIDA'],
    ['validade', '19/10/2026', 'CNH_VENCIDA'],
    ['categoria', null, 'CATEGORIA_NAO_LIDA'],
    ['categoria', 'A', 'CATEGORIA_INCOMPATIVEL'],
  ] as const)('recusa campo %s inválido: %s', (campo, valor, motivo) => {
    const l = leitura();
    l.campos![campo] = valor;
    expect(conferir(l).motivo).toBe(motivo);
  });
  it.each(['529.982 .247-25', '529 982 247 25'])(
    'tolera espaços do OCR no CPF',
    (cpf) => {
      const l = leitura();
      l.campos!.cpf = cpf;
      expect(conferir(l).dados?.cpf).toBe('52998224725');
    },
  );
  it.each(['06 / 10 / 2030', '06.10.2030'])(
    'aceita data inequívoca',
    (data) => {
      const l = leitura();
      l.campos!.validade = data;
      expect(conferir(l).dados?.validade).toBe('2030-10-06');
    },
  );
  it('não usa texto geral para preencher campo ausente', () => {
    const l = leitura();
    l.campos!.cpf = null;
    l.texto = 'CPF 529.982.247-25';
    expect(conferir(l).motivo).toBe('CPF_NAO_LIDO');
    l.nome = null;
    expect(conferir(l).motivo).toBe('NOME_NAO_LIDO');
  });
  it('valida nome completo e CPF', () => {
    expect(nomeCompletoValido('João')).toBe(false);
    expect(nomeCompletoValido('123 Silva')).toBe(false);
    expect(nomeCompletoValido('João D’Ávila')).toBe(true);
    expect(cpfValido('52998224725')).toBe(true);
    expect(cpfValido('00000000000')).toBe(false);
  });
});
