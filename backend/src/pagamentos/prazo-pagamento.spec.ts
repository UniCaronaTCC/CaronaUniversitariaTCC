import {
  calcularDuracaoPixSegundos,
  calcularLimitePagamento,
  DURACAO_MAXIMA_PIX_SEGUNDOS,
} from './prazo-pagamento';

describe('prazos de pagamento', () => {
  const agora = new Date('2026-09-15T12:00:00.000Z');

  it('limita o pagamento a uma hora depois do aceite', () => {
    expect(calcularLimitePagamento('2026-09-15', '14:00:00', agora)).toEqual(
      new Date('2026-09-15T13:00:00.000Z'),
    );
  });

  it('encerra o prazo quinze minutos antes de uma carona proxima', () => {
    expect(calcularLimitePagamento('2026-09-15', '10:00:00', agora)).toEqual(
      new Date('2026-09-15T12:45:00.000Z'),
    );
  });

  it('produz um prazo encerrado dentro dos quinze minutos finais', () => {
    expect(
      calcularLimitePagamento('2026-09-15', '09:10:00', agora).getTime(),
    ).toBeLessThanOrEqual(agora.getTime());
  });

  it('limita o Pix a trinta minutos', () => {
    const limite = new Date('2026-09-15T13:00:00.000Z');

    expect(calcularDuracaoPixSegundos(limite, agora)).toBe(
      DURACAO_MAXIMA_PIX_SEGUNDOS,
    );
  });

  it('reduz a validade do Pix quando resta menos de trinta minutos', () => {
    const limite = new Date('2026-09-15T12:10:00.000Z');

    expect(calcularDuracaoPixSegundos(limite, agora)).toBe(600);
  });
});
