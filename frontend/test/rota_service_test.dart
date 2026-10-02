import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/services/rota_service.dart';

void main() {
  const pontos = [LatLng(-21.2, -50.4), LatLng(-21.1, -50.3)];

  test('envia longitude antes da latitude e interpreta a resposta', () async {
    final service = RotaService(
      criarCliente: () => MockClient((request) async {
        expect(jsonDecode(request.body)['coordenadas'], [
          [-50.4, -21.2],
          [-50.3, -21.1],
        ]);
        return http.Response(
          jsonEncode({
            'pontos': [
              [-21.2, -50.4],
              [-21.1, -50.3],
            ],
            'distanciaMetros': 2000,
            'duracaoSegundos': 300,
          }),
          200,
        );
      }),
    );
    final rota = await service.calcularRota(pontos);
    expect(rota.pontos, pontos);
    expect(rota.distanciaMetros, 2000);
  });

  test(
    'pontos agrupados no destino não fazem uma requisição inválida',
    () async {
      final service = RotaService(criarCliente: () => throw StateError('HTTP'));
      final rota = await service.calcularRota([pontos.first]);
      expect(rota.pontos, [pontos.first, pontos.first]);
      expect(rota.distanciaMetros, 0);
    },
  );

  test('rejeita resposta sem geometria útil ou resumo válido', () async {
    for (final distancia in [-1, 200]) {
      final service = RotaService(
        criarCliente: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'pontos': distancia < 0
                  ? [
                      [-21.2, -50.4],
                      [-21.1, -50.3],
                    ]
                  : [],
              'distanciaMetros': distancia,
              'duracaoSegundos': 300,
            }),
            200,
          ),
        ),
      );
      await expectLater(service.calcularRota(pontos), throwsFormatException);
    }
  });

  test('erro do servidor encerra a consulta', () async {
    final service = RotaService(
      criarCliente: () => MockClient((_) async => http.Response('', 504)),
    );
    await expectLater(service.calcularRota(pontos), throwsException);
  });
}
