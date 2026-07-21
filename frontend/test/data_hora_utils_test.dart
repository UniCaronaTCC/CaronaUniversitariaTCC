import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/utils/data_hora_utils.dart';

void main() {
  test('formata data para exibicao e backend', () {
    final data = DateTime(2026, 7, 5);

    expect(DataHoraUtils.formatarDataExibicao(data), '05/07/2026');
    expect(DataHoraUtils.formatarDataBackend(data), '2026-07-05');
  });

  test('formata horario com dois digitos', () {
    const horario = TimeOfDay(hour: 7, minute: 5);

    expect(DataHoraUtils.formatarHorario(horario), '07:05');
  });
}
