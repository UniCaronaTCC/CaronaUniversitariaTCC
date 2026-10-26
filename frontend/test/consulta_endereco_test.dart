import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/mapa/models/consulta_endereco.dart';

void main() {
  for (final texto in [
    'Rua Brasil, 123',
    'Rua Brasil 123',
    'Av. Brasil, 123A',
  ]) {
    test('separa numero de casa em $texto sem alterar a consulta original', () {
      final consulta = ConsultaEndereco(texto);
      expect(consulta.texto, texto);
      expect(consulta.numero, texto.endsWith('A') ? '123A' : '123');
      expect(
        consulta.semNumero,
        texto.startsWith('Av.') ? 'Av. Brasil' : 'Rua Brasil',
      );
    });
  }
  for (final texto in [
    'Rua 7 de Setembro',
    'Avenida 9 de Julho',
    'Rua 25',
    'Rua 7',
    'BR-153',
    'SP-300',
    'Rodovia Marechal Rondon km 12',
    'Bloco 2',
    'Campus 1',
    '',
  ]) {
    test('nao remove identificador numerico de $texto', () {
      final consulta = ConsultaEndereco(texto);
      expect(consulta.numero, isNull);
      expect(consulta.semNumero, isNull);
    });
  }
  test('preserva numero do nome da rua e cidade ao retirar numero da casa', () {
    final consulta = ConsultaEndereco('Rua 7 de Setembro, 123, Araçatuba, SP');
    expect(consulta.semNumero, 'Rua 7 de Setembro, Araçatuba, SP');
    expect(consulta.cidadeExplicita('Aracatuba'), isTrue);
    expect(consulta.cidadeExplicita('Sao Paulo'), isFalse);
  });
  test('palavras comuns e nome da rua nao sao cidade explicita', () {
    expect(ConsultaEndereco('Rua São João').cidadeExplicita('São João'), false);
    expect(
      ConsultaEndereco('shopping rio').cidadeExplicita('Rio de Janeiro'),
      false,
    );
    expect(ConsultaEndereco('UFPR Curitiba').cidadeExplicita('Curitiba'), true);
    expect(
      ConsultaEndereco('Rua Brasil, São Paulo').cidadeExplicita('São Paulo'),
      true,
    );
  });
  test('normaliza abreviacoes do logradouro sem juntar palavras', () {
    expect(
      ConsultaEndereco.normalizarLogradouro('R. São João'),
      'rua sao joao',
    );
    expect(
      ConsultaEndereco.normalizarLogradouro('Av. Brasil'),
      'avenida brasil',
    );
    expect(ConsultaEndereco.normalizarLogradouro('TV. Azul'), 'travessa azul');
  });
}
