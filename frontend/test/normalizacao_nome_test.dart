import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/utils/normalizacao_nome.dart';

void main() {
  final casos = {
    'joão da Silva': 'João da Silva',
    'henrique': 'Henrique',
    '  áLVARO de Souza  ': 'ÁLVARO de Souza',
    '\télio\n': 'Élio',
    'ana-Maria': 'Ana-Maria',
    'João': 'João',
    'JOÃO': 'JOÃO',
    'j': 'J',
    '': '',
    '   ': '',
  };
  for (final caso in casos.entries) {
    test('normaliza inicial de "${caso.key}" preservando restante', () {
      expect(normalizarNomeUsuario(caso.key), caso.value);
      expect(normalizarNomeUsuario(caso.value), caso.value);
    });
  }
}
