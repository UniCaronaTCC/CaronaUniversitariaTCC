import { partidaNoFuturo } from './partida-carona';

describe('Horario de partida para novas solicitacoes', () => {
  const carona = { dataInicio: '2026-11-03', horario: '18:35:00' };
  it.each([
    ['2026-11-03T21:34:59.999Z', true],
    ['2026-11-03T21:35:00.000Z', false],
    ['2026-11-03T23:19:00.000Z', false],
    ['2026-11-03T20:19:00.000Z', true],
    ['2026-11-04T00:00:00.000Z', false],
  ])('confere o horario de Brasilia em %s', (instante, esperado) => {
    expect(partidaNoFuturo(carona, new Date(instante))).toBe(esperado);
  });
  it('mantem as partidas dos proximos dias', () => {
    expect(
      partidaNoFuturo(
        { ...carona, dataInicio: '2026-11-04' },
        new Date('2026-11-03T23:19:00Z'),
      ),
    ).toBe(true);
  });
  it('nao libera nova solicitacao sem uma partida valida', () => {
    expect(partidaNoFuturo({ ...carona, horario: 'invalido' })).toBe(false);
  });
});
