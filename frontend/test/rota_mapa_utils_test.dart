import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/utils/rota_mapa_utils.dart';
import 'package:uni_carona/models/carona.dart';

void main() {
  test('navegação começa na posição atual do motorista', () {
    final carona = Carona(
      id: 1,
      origem: 'Origem cadastrada',
      origemLatitude: -21.3,
      origemLongitude: -50.5,
      destino: 'Destino',
      destinoLatitude: -21.1,
      destinoLongitude: -50.3,
      dataInicio: DateTime(2026, 9, 14),
      horario: '18:00:00',
      vagas: 2,
      valor: 5,
      recorrente: false,
      diasSemana: const [],
      motorista: 'Motorista',
    );
    const posicaoMotorista = LatLng(-21.2, -50.4);

    final paradas = paradasDaNavegacao(carona, posicaoMotorista, const {});

    expect(paradas, isNotNull);
    expect(paradas!.first, posicaoMotorista);
    expect(paradas.first, isNot(const LatLng(-21.3, -50.5)));
  });
}
