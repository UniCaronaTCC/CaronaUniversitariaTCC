import { extrairDadosCnh } from './dados-cnh';

describe('extração de dados da CNH', () => {
  const hoje = '2026-10-06';
  const texto = [
    'NOME E SOBRENOME',
    'JOÃO PEDRO DA SILVA',
    'CPF 529.982.247-25',
    'CATEGORIA AB',
    'VALIDADE 06/10/2030',
    'Nº REGISTRO 12345678901',
  ].join('\n');

  it('extrai apenas os dados necessários de uma leitura coerente', () => {
    expect(extrairDadosCnh(texto, 'João Pedro da Silva', hoje)).toEqual({
      cpf: '52998224725',
      categoria: 'AB',
      validade: '2030-10-06',
      registroFinal: '8901',
    });
  });

  it('aceita o rótulo abreviado de categoria', () => {
    const leitura = texto.replace('CATEGORIA AB', 'CAT. HAB. AB');
    expect(
      extrairDadosCnh(leitura, 'João Pedro da Silva', hoje)?.categoria,
    ).toBe('AB');
  });

  it.each([
    ['nome divergente', texto.replace('JOÃO PEDRO DA SILVA', 'MARIA SILVA')],
    ['CPF inválido', texto.replace('529.982.247-25', '111.111.111-11')],
    ['CNH vencida', texto.replace('06/10/2030', '05/10/2026')],
    ['data impossível', texto.replace('06/10/2030', '31/02/2030')],
    ['categoria A', texto.replace('CATEGORIA AB', 'CATEGORIA A')],
    ['registro ausente', texto.replace('12345678901', '')],
  ])('não aprova %s', (_cenario, leitura) => {
    expect(extrairDadosCnh(leitura, 'João Pedro da Silva', hoje)).toBeNull();
  });

  it('não aprova texto vazio', () => {
    expect(extrairDadosCnh('', 'João Pedro da Silva', hoje)).toBeNull();
  });
});
