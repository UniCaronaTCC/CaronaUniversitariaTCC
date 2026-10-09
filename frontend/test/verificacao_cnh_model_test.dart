import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/verificacao_cnh.dart';

void main() {
  test('considera o dia de São Paulo na validade, inclusive à meia-noite', () {
    final cnh = VerificacaoCnh.fromPerfil({
      'statusVerificacaoCnh': 'APROVADA',
      'cnhCategoria': 'AB',
      'cnhValidade': '2026-10-07',
    });
    expect(
      cnh.permiteOferecerCarona(DateTime.parse('2026-10-08T02:59:59Z')),
      isTrue,
    );
    expect(
      cnh.permiteOferecerCarona(DateTime.parse('2026-10-08T03:00:00Z')),
      isFalse,
    );
    expect(cnh.validadeFormatada, '07/10/2026');
  });

  test('não libera status pendente, categoria A ou dados incompletos', () {
    for (final perfil in [
      <String, dynamic>{},
      {'statusVerificacaoCnh': 'EM_ANALISE'},
      {
        'statusVerificacaoCnh': 'APROVADA',
        'cnhCategoria': 'A',
        'cnhValidade': '2099-10-07',
      },
      {'statusVerificacaoCnh': 'APROVADA', 'cnhCategoria': 'B'},
    ]) {
      expect(
        VerificacaoCnh.fromPerfil(perfil).permiteOferecerCarona(),
        isFalse,
      );
    }
  });
}
