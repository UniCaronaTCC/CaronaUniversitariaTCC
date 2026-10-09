import {
  extrairDadosCnh,
  conferirDadosCnh,
  nomeCompletoValido,
} from './dados-cnh';

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

  it('aceita nome em duas linhas e categoria sem espaço', () => {
    const leitura = texto
      .replace('JOÃO PEDRO DA SILVA', 'JOÃO PEDRO\nDA SILVA')
      .replace('CATEGORIA AB', 'CAT.HAB. AB');
    expect(
      extrairDadosCnh(leitura, '  João   Pedro da Silva ', hoje)?.categoria,
    ).toBe('AB');
  });

  it.each([
    'João',
    'Pedro da Silva',
    'João Pedro',
    'João Pedro da Silva Junior',
  ])('não aceita nome parcial ou diferente: %s', (nome) => {
    expect(conferirDadosCnh(texto, nome, hoje)).toEqual({
      dados: null,
      motivo: 'NOME_DIVERGENTE',
    });
  });

  it('não usa o nome da filiação como nome do titular', () => {
    const leitura = texto.replace(
      'JOÃO PEDRO DA SILVA',
      'MARIA SILVA\nFILIAÇÃO\nJOÃO PEDRO DA SILVA',
    );
    expect(extrairDadosCnh(leitura, 'João Pedro da Silva', hoje)).toBeNull();
  });

  it.each([
    ['CPF_NAO_LIDO', texto.replace('CPF 529.982.247-25', '')],
    ['CPF_INVALIDO', texto.replace('529.982.247-25', '111.111.111-11')],
    ['CATEGORIA_INCOMPATIVEL', texto.replace('CATEGORIA AB', 'CATEGORIA A')],
    ['CNH_VENCIDA', texto.replace('06/10/2030', '05/10/2026')],
    ['REGISTRO_NAO_LIDO', texto.replace('12345678901', '')],
  ])('explica a recusa %s sem devolver os dados lidos', (motivo, leitura) => {
    expect(conferirDadosCnh(leitura, 'João Pedro da Silva', hoje)).toEqual({
      dados: null,
      motivo,
    });
  });

  it('valida nome completo informado', () => {
    expect(nomeCompletoValido('Henrique')).toBe(false);
    expect(nomeCompletoValido('123 Silva')).toBe(false);
    expect(nomeCompletoValido('João D’Ávila')).toBe(true);
  });

  it.each(['529.982 .247-25', '529 . 982 . 247 - 25', '529 982 247 25'])(
    'tolera espaços no CPF %s',
    (cpf) => {
      expect(
        extrairDadosCnh(
          texto.replace('529.982.247-25', cpf),
          'João Pedro da Silva',
          hoje,
        )?.cpf,
      ).toBe('52998224725');
    },
  );

  it.each(['123 45678901', '1 2 3 4 5 6 7 8 9 0 1'])(
    'tolera espaços no registro %s',
    (registro) => {
      expect(
        extrairDadosCnh(
          texto.replace('12345678901', registro),
          'João Pedro da Silva',
          hoje,
        )?.registroFinal,
      ).toBe('8901');
    },
  );

  it.each(['06 / 10 / 2030', '06.10.2030', '\n06/10/2030'])(
    'aceita data inequívoca %s',
    (data) => {
      expect(
        extrairDadosCnh(
          texto.replace('06/10/2030', data),
          'João Pedro da Silva',
          hoje,
        )?.validade,
      ).toBe('2030-10-06');
    },
  );

  it.each([
    'VALIDADE\nEXAME MEDICO 06/10/2030\n05/10/2026',
    'DATA EMISSAO VALIDADE\n06/10/2020 06/10/2030',
    'VALIDADE 06/10/2030 05/10/2026',
    'VALIDADE 06/10/2030\n05/10/2026',
    'VALIDADE 06/10/2030\nVALIDADE 05/10/2026',
    'VALIDADE\nEMISSAO 06/10/2030',
  ])('não escolhe uma data em leitura ambígua: %s', (campo) => {
    expect(
      conferirDadosCnh(
        texto.replace('VALIDADE 06/10/2030', campo),
        'João Pedro da Silva',
        hoje,
      ),
    ).toEqual({ dados: null, motivo: 'VALIDADE_NAO_LIDA' });
  });

  it.each([
    ['CPF 529.982.247-25', 'CPF\nREGISTRO 52998224725'],
    ['CPF 529.982.247-25', 'CPF 529982247251'],
    ['CPF 529.982.247-25', 'CPF 52998224725 52998224725'],
    ['CPF 529.982.247-25', 'CPF 529.982 .247-24'],
    ['Nº REGISTRO 12345678901', 'N REGISTRO\nCPF 52998224725'],
    ['Nº REGISTRO 12345678901', 'N REGISTRO 123456789012'],
    ['CATEGORIA AB', 'CATEGORIA\nOBSERVACOES B'],
    ['CATEGORIA AB', 'CATEGORIA A\nCATEGORIA B'],
    ['VALIDADE 06/10/2030', 'VALIDADE 31 / 02 / 2030'],
  ])(
    'recusa número inválido ou pertencente a outro campo: %s',
    (original, campo) => {
      expect(
        extrairDadosCnh(
          texto.replace(original, campo),
          'João Pedro da Silva',
          hoje,
        ),
      ).toBeNull();
    },
  );
});
