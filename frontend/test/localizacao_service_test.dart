import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/mapa/services/localizacao_service.dart';

void main() {
  test('usa o intervalo para aceitar deslocamentos normais em rodovia', () {
    final filtro = FiltroLocalizacaoGps();
    final inicio = DateTime(2026, 10, 28, 12);
    for (var indice = 0; indice < 4; indice++) {
      expect(
        filtro.aceitar(
          latitude: -21.2,
          longitude: -50.4 + indice * 0.0014,
          precisao: 8,
          instante: inicio.add(Duration(seconds: indice * 5)),
        ),
        isTrue,
      );
    }
  });

  test('continua rejeitando um salto isolado e retoma a posição real', () {
    final filtro = FiltroLocalizacaoGps();
    final inicio = DateTime(2026, 10, 28, 12);
    expect(
      filtro.aceitar(
        latitude: -21.2,
        longitude: -50.4,
        precisao: 8,
        instante: inicio,
      ),
      isTrue,
    );
    expect(
      filtro.aceitar(
        latitude: -21.19,
        longitude: -50.39,
        precisao: 8,
        instante: inicio.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      filtro.aceitar(
        latitude: -21.2,
        longitude: -50.3999,
        precisao: 8,
        instante: inicio.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
  });

  test(
    'não interpreta como movimento uma leitura repetida ou fora de ordem',
    () {
      final filtro = FiltroLocalizacaoGps();
      final inicio = DateTime(2026, 10, 28, 12);
      expect(
        filtro.aceitar(
          latitude: -21.2,
          longitude: -50.4,
          precisao: 8,
          instante: inicio,
        ),
        isTrue,
      );
      for (final segundos in [0, -1]) {
        expect(
          filtro.aceitar(
            latitude: -21.2,
            longitude: -50.4,
            precisao: 8,
            instante: inicio.add(Duration(seconds: segundos)),
          ),
          isFalse,
        );
      }
    },
  );

  test('ignora localização imprecisa e confirma salto com segunda leitura', () {
    final filtro = FiltroLocalizacaoGps();
    final inicio = DateTime(2026, 10, 28, 12);

    expect(
      filtro.aceitar(
        latitude: -21.208,
        longitude: -50.432,
        precisao: 80,
        instante: inicio,
      ),
      isFalse,
    );
    expect(
      filtro.aceitar(
        latitude: -21.208,
        longitude: -50.432,
        precisao: 8,
        instante: inicio.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );

    expect(
      filtro.aceitar(
        latitude: -21.198,
        longitude: -50.422,
        precisao: 8,
        instante: inicio.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      filtro.aceitar(
        latitude: -21.19801,
        longitude: -50.42201,
        precisao: 8,
        instante: inicio.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
  });
}
