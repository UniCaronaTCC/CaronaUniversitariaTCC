import { ValidacaoCarona } from './validacao-carona';

describe('Validação de programação', () => {
  const validacao = new ValidacaoCarona();
  const dados = {
    origem: 'Rua A',
    destino: 'Rua B',
    dataInicio: '2026-09-28',
    horario: '18:00:00',
    vagas: 3,
    valor: 5,
    recorrente: true,
    diasSemana: ['SEG', 'TER'],
    origemLatitude: -21,
    origemLongitude: -50,
    destinoLatitude: -21,
    destinoLongitude: -50,
  };
  it.each([
    { diasSemana: [] },
    { diasSemana: ['XXX'] },
    { dataInicio: '2026-02-30' },
    { horario: '25:00:00' },
    { dataFim: '2026-09-27' },
    { origemLatitude: null },
  ])('rejeita configuração inválida %j', (alteracao) => {
    expect(() =>
      validacao.validarDadosCarona({ ...dados, ...alteracao }, 1),
    ).toThrow();
  });
  it('remove dias repetidos e usa o motorista autenticado', () => {
    const resultado = validacao.validarDadosCarona(
      { ...dados, idUsuario: 999, diasSemana: ['SEG', 'SEG', 'TER'] },
      1,
    );
    expect(resultado.idUsuario).toBe(1);
    expect(resultado.diasSemana).toEqual(['SEG', 'TER']);
  });

  it.each([undefined, {}, { vagas: 4 }])(
    'recusa contrato antigo de edicao %j',
    (body) => {
      expect(() => validacao.validarEdicaoCarona(body, 1)).toThrow(
        'Atualize o aplicativo',
      );
    },
  );

  it.each([null, '', '3', true, 0, -1, 5, 1.5])(
    'recusa capacidade de edicao invalida %j',
    (valor) => {
      for (const campo of ['capacidadePassageiros', 'capacidadeAnterior']) {
        expect(() =>
          validacao.validarEdicaoCarona(
            {
              ...dados,
              capacidadePassageiros: 3,
              capacidadeAnterior: 4,
              [campo]: valor,
            },
            1,
          ),
        ).toThrow('capacidade');
      }
    },
  );

  it('usa capacidade explicita e ignora vagas livres e identidade enviados pelo cliente', () => {
    const resultado = validacao.validarEdicaoCarona(
      {
        ...dados,
        recorrente: false,
        idUsuario: 999,
        vagas: 99,
        capacidadePassageiros: 3,
        capacidadeAnterior: 4,
      },
      1,
    );
    expect(resultado).toMatchObject({
      idUsuario: 1,
      capacidadePassageiros: 3,
      capacidadeAnterior: 4,
    });
    expect(resultado).not.toHaveProperty('vagas');
  });
});
