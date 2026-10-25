import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/dados_veiculo.dart';

void main() {
  for (final modelo in [
    'Honda Civic',
    '208',
    'C3',
    'HB20 1.0',
    'F-1000',
    'Citro\u00ebn C4',
    'BYD Dolphin',
    'VW up!',
    'Chrysler Town & Country',
  ]) {
    test(
      'aceita modelo $modelo',
      () => expect(DadosVeiculo.validarModelo(modelo), isNull),
    );
  }
  for (final modelo in [
    null,
    '',
    ' ',
    '@@',
    '<script>',
    'A',
    'x' * 101,
    'Honda\nCivic',
    'Honda\tCivic',
    'Civic\u200b',
  ]) {
    test(
      'recusa modelo $modelo',
      () => expect(DadosVeiculo.validarModelo(modelo), isNotNull),
    );
  }
  for (final cor in [
    'Prata',
    'Azul escuro',
    'Gren\u00e1',
    'Azul-met\u00e1lico',
    'Fantasia',
  ]) {
    test('aceita cor $cor', () => expect(DadosVeiculo.validarCor(cor), isNull));
  }
  for (final cor in [
    null,
    '',
    ' ',
    '!!',
    '99',
    'Azul123',
    'A',
    'x' * 51,
    'Azul\nclaro',
    'Azul\u200b',
  ]) {
    test(
      'recusa cor $cor',
      () => expect(DadosVeiculo.validarCor(cor), isNotNull),
    );
  }
  for (final placa in [
    'ABC1D23',
    'abc-1d23',
    'ABC 1D23',
    'ABC1234',
    'abc-1234',
  ]) {
    test(
      'aceita placa $placa',
      () => expect(DadosVeiculo.validarPlaca(placa), isNull),
    );
  }
  for (final placa in [
    null,
    '',
    '1234567',
    'ABC12D3',
    'ABC1D234',
    'ABC@1D23',
    'ABC\n1D23',
    'A' * 33,
  ]) {
    test(
      'recusa placa $placa',
      () => expect(DadosVeiculo.validarPlaca(placa), isNotNull),
    );
  }
  test('normaliza espacos e placa, reconhece cor sem acentos', () {
    expect(DadosVeiculo.normalizarTexto('  Honda   Civic '), 'Honda Civic');
    expect(DadosVeiculo.normalizarPlaca(' abc-1234 '), 'ABC1234');
    expect(DadosVeiculo.corPadrao(' GRENA '), 'Gren\u00e1');
    expect(DadosVeiculo.corPadrao('Azul escuro'), isNull);
  });
  test('aceita limites do banco', () {
    expect(DadosVeiculo.validarModelo('A' * 100), isNull);
    expect(DadosVeiculo.validarCor('A' * 50), isNull);
  });
}
