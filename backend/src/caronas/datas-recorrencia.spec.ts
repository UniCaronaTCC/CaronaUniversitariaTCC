import {
  datasRecorrencia,
  validarData,
  dataEmBrasilia,
} from './datas-recorrencia';

describe('Datas de recorrência', () => {
  const dados = {
    dataInicio: '2026-09-28',
    dataFim: null,
    horario: '18:00:00',
    diasSemana: ['SEG', 'TER'],
  };
  it('gera segundas e terças independentes em duas semanas', () => {
    expect(datasRecorrencia(dados, new Date('2026-09-26T15:00:00Z'))).toEqual([
      '2026-09-28',
      '2026-09-29',
      '2026-10-05',
      '2026-10-06',
    ]);
  });
  it('respeita o fim e não publica partida passada de hoje', () => {
    expect(
      datasRecorrencia(
        { ...dados, dataFim: '2026-09-29' },
        new Date('2026-09-28T21:01:00Z'),
      ),
    ).toEqual(['2026-09-29']);
  });
  it('completa datas futuras após ficar dias desligado, sem recriar o passado', () => {
    expect(datasRecorrencia(dados, new Date('2026-10-06T22:00:00Z'))).toEqual([
      '2026-10-12',
      '2026-10-13',
      '2026-10-19',
    ]);
  });
  it('usa a data de Brasília durante a virada do dia UTC', () => {
    expect(dataEmBrasilia(new Date('2026-09-29T01:00:00Z'))).toBe('2026-09-28');
  });
  it('não duplica dias repetidos e atravessa o ano', () => {
    expect(
      datasRecorrencia(
        { ...dados, dataInicio: '2026-12-28', diasSemana: ['SEG', 'SEG'] },
        new Date('2026-12-27T15:00:00Z'),
      ),
    ).toEqual(['2026-12-28', '2027-01-04']);
  });
  it.each(['2026-02-30', '2026-13-01', '28/09/2026', ''])(
    'rejeita data inválida %s',
    (data) => {
      expect(() => validarData(data)).toThrow();
    },
  );
});
