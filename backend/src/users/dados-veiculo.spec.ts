import { BadRequestException } from '@nestjs/common';
import { validarDadosVeiculo } from './dados-veiculo';

const valido = { modelo: 'Honda Civic', cor: 'Prata', placa: 'ABC1D23' };

describe('dados do veiculo', () => {
  it.each([
    'Honda Civic',
    '208',
    'C3',
    'HB20 1.0',
    'F-1000',
    'Citro\u00ebn C4',
    'BYD Dolphin',
    'VW up!',
    'Chrysler Town & Country',
  ])('aceita modelo %s', (modelo) => {
    expect(validarDadosVeiculo({ ...valido, modelo }).modelo).toBe(modelo);
  });

  it.each([
    'Prata',
    'Azul escuro',
    'Gren\u00e1',
    'Azul-met\u00e1lico',
    'Fantasia',
  ])('preserva cor legitima %s', (cor) => {
    expect(validarDadosVeiculo({ ...valido, cor }).cor).toBe(cor);
  });

  it.each(['ABC1D23', 'abc-1d23', 'ABC 1D23', 'ABC1234', 'abc-1234'])(
    'normaliza placa %s',
    (placa) => {
      expect(validarDadosVeiculo({ ...valido, placa }).placa).toBe(
        placa.toUpperCase().replace(/[ -]/g, ''),
      );
    },
  );

  it('normaliza espacos sem alterar a grafia do modelo e da cor', () => {
    expect(
      validarDadosVeiculo({
        modelo: '  Honda   Civic  ',
        cor: '  Azul   escuro  ',
        placa: ' ABC-1234 ',
      }),
    ).toEqual({ modelo: 'Honda Civic', cor: 'Azul escuro', placa: 'ABC1234' });
  });

  it.each(['modelo', 'cor', 'placa'] as const)(
    'recusa tipos JSON invalidos em %s',
    (campo) => {
      for (const valor of [
        undefined,
        null,
        123,
        true,
        {},
        [],
        ['Azul'],
        { toString: 'texto' },
      ]) {
        try {
          validarDadosVeiculo({ ...valido, [campo]: valor });
          throw new Error('Deveria recusar');
        } catch (erro) {
          expect(erro).toBeInstanceOf(BadRequestException);
          expect((erro as BadRequestException).getStatus()).toBe(400);
          expect((erro as BadRequestException).getResponse()).toHaveProperty(
            `campos.${campo}`,
          );
        }
      }
    },
  );

  it.each([null, undefined, [], 'texto', 123])(
    'recusa corpo invalido %j',
    (body) => {
      expect(() => validarDadosVeiculo(body)).toThrow(BadRequestException);
    },
  );

  it.each([
    '',
    ' ',
    '@@',
    '<script>',
    'A',
    'x'.repeat(101),
    'Honda\nCivic',
    'Honda\tCivic',
    'Civic\u200b',
  ])('recusa modelo invalido %j', (modelo) => {
    expect(() => validarDadosVeiculo({ ...valido, modelo })).toThrow(
      BadRequestException,
    );
  });

  it.each([
    '',
    ' ',
    '!!',
    '99',
    'Azul123',
    'A',
    'x'.repeat(51),
    'Azul\nclaro',
    'Azul\u200b',
  ])('recusa cor invalida %j', (cor) => {
    expect(() => validarDadosVeiculo({ ...valido, cor })).toThrow(
      BadRequestException,
    );
  });

  it.each([
    '',
    '1234567',
    'ABC12D3',
    'ABC1D234',
    'ABC@1D23',
    'ABC\n1D23',
    'A'.repeat(33),
  ])('recusa placa invalida %j', (placa) => {
    expect(() => validarDadosVeiculo({ ...valido, placa })).toThrow(
      BadRequestException,
    );
  });

  it('aceita limites de tamanho do banco', () => {
    expect(
      validarDadosVeiculo({
        ...valido,
        modelo: 'A'.repeat(100),
        cor: 'A'.repeat(50),
      }),
    ).toMatchObject({ modelo: 'A'.repeat(100), cor: 'A'.repeat(50) });
  });
});
