import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/utils/validacao_senha.dart';

void main() {
  test('aceita senha com oito caracteres, letras e números', () {
    expect(ValidacaoSenha.ehValida('carona123'), isTrue);
  });

  test('recusa senha curta ou sem letras e números', () {
    expect(ValidacaoSenha.ehValida('abc123'), isFalse);
    expect(ValidacaoSenha.ehValida('abcdefgh'), isFalse);
    expect(ValidacaoSenha.ehValida('12345678'), isFalse);
  });
}
