import { User } from './user.entity';
import { cnhPermiteOferecerCarona } from './verificacao-cnh';

describe('liberação para oferecer carona', () => {
  const hoje = '2026-10-06';
  const aprovada = {
    statusVerificacaoCnh: 'APROVADA' as const,
    cnhCategoria: 'B',
    cnhValidade: '2027-01-01',
  };

  it('não inicializa dados privados omitidos das consultas comuns', () => {
    const usuario = new User();
    expect(usuario.cpf).toBeUndefined();
    expect(usuario.cnhRegistroFinal).toBeUndefined();
  });

  it.each(['B', 'AB', 'C', 'AC', 'D', 'AD', 'E', 'AE'])(
    'permite categoria %s com CNH aprovada e válida',
    (cnhCategoria) => {
      expect(
        cnhPermiteOferecerCarona({ ...aprovada, cnhCategoria }, hoje),
      ).toBe(true);
    },
  );

  it('permite no último dia da validade', () => {
    expect(
      cnhPermiteOferecerCarona({ ...aprovada, cnhValidade: hoje }, hoje),
    ).toBe(true);
  });

  it.each(['NAO_ENVIADA', 'EM_ANALISE', 'RECUSADA'] as const)(
    'bloqueia status %s',
    (statusVerificacaoCnh) => {
      expect(
        cnhPermiteOferecerCarona({ ...aprovada, statusVerificacaoCnh }, hoje),
      ).toBe(false);
    },
  );

  it.each([
    { cnhCategoria: 'A' },
    { cnhCategoria: 'X' },
    { cnhCategoria: null },
    { cnhValidade: '2026-10-05' },
    { cnhValidade: null },
    { cnhValidade: '06/10/2026' },
  ])('bloqueia dados incompletos ou inválidos: %j', (alteracao) => {
    expect(cnhPermiteOferecerCarona({ ...aprovada, ...alteracao }, hoje)).toBe(
      false,
    );
  });
});
