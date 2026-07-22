import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/utils/formatador_data.dart';

void main() {
  final referencia = DateTime(2026, 7, 22, 15, 30);

  test('mostra Hoje para a data atual', () {
    expect(
      FormatadorData.relativa(DateTime(2026, 7, 22), referencia: referencia),
      'Hoje',
    );
  });

  test('mostra Amanhã para o dia seguinte', () {
    expect(
      FormatadorData.relativa(DateTime(2026, 7, 23), referencia: referencia),
      'Amanhã',
    );
  });

  test('mantém a data completa nos demais dias', () {
    expect(
      FormatadorData.relativa(DateTime(2026, 7, 25), referencia: referencia),
      '25/07',
    );
  });
}
