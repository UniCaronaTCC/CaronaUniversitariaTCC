import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/utils/validacao_email.dart';

void main() {
  test('aceita e-mail com formato válido', () {
    expect(ValidacaoEmail.ehValido('usuario@email.com'), isTrue);
    expect(ValidacaoEmail.ehValido('usuario@email.com.br'), isTrue);
  });

  test('recusa e-mail com formato inválido', () {
    expect(ValidacaoEmail.ehValido('usuario'), isFalse);
    expect(ValidacaoEmail.ehValido('usuario@email'), isFalse);
    expect(ValidacaoEmail.ehValido('@email.com'), isFalse);
  });
}
