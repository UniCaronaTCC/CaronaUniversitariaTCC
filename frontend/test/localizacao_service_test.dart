import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/mapa/services/localizacao_service.dart';

void main() {
  test('ignora localização imprecisa e confirma salto com segunda leitura', () {
    final filtro = FiltroLocalizacaoGps();

    expect(
      filtro.aceitar(latitude: -21.208, longitude: -50.432, precisao: 80),
      isFalse,
    );
    expect(
      filtro.aceitar(latitude: -21.208, longitude: -50.432, precisao: 8),
      isTrue,
    );

    expect(
      filtro.aceitar(latitude: -21.198, longitude: -50.422, precisao: 8),
      isFalse,
    );
    expect(
      filtro.aceitar(latitude: -21.19801, longitude: -50.42201, precisao: 8),
      isTrue,
    );
  });
}
