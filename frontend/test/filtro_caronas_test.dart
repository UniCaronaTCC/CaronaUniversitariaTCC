import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/utils/filtro_caronas.dart';

void main() {
  test('horário preferido ordena sem remover caronas', () {
    final caronas = [
      criarCarona(id: 1, horario: '18:00:00'),
      criarCarona(id: 2, horario: '19:10:00'),
    ];

    final resultado = FiltroCaronas.aplicar(
      caronas: caronas,
      destino: 'UniSalesiano',
      horarioPreferidoEmMinutos: 19 * 60,
    );

    expect(resultado, hasLength(2));
    expect(resultado.first.id, 2);
  });

  test('destino mais próximo aparece primeiro', () {
    final caronas = [
      criarCarona(id: 1, destinoLatitude: -23.5505, destinoLongitude: -46.6333),
      criarCarona(id: 2, destinoLatitude: -21.201, destinoLongitude: -50.401),
    ];

    final resultado = FiltroCaronas.aplicar(
      caronas: caronas,
      destino: 'UniSalesiano',
      destinoLatitude: -21.2,
      destinoLongitude: -50.4,
    );

    expect(resultado.first.id, 2);
  });

  test('data selecionada continua filtrando as caronas', () {
    final caronas = [
      criarCarona(id: 1, dataInicio: DateTime(2026, 7, 23)),
      criarCarona(id: 2, dataInicio: DateTime(2026, 7, 24)),
    ];

    final resultado = FiltroCaronas.aplicar(
      caronas: caronas,
      data: DateTime(2026, 7, 24),
    );

    expect(resultado, hasLength(1));
    expect(resultado.first.id, 2);
  });
}

Carona criarCarona({
  required int id,
  String horario = '19:00:00',
  DateTime? dataInicio,
  double? destinoLatitude,
  double? destinoLongitude,
}) {
  return Carona(
    id: id,
    origem: 'Centro',
    destino: 'UniSalesiano',
    destinoLatitude: destinoLatitude,
    destinoLongitude: destinoLongitude,
    dataInicio: dataInicio ?? DateTime(2026, 7, 23),
    horario: horario,
    vagas: 3,
    valor: 5,
    recorrente: false,
    diasSemana: const [],
    motorista: 'Motorista',
  );
}
