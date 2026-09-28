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
});
