import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/services/rota_service.dart';
import 'package:uni_carona/mapa/widgets/mapa_navegacao_carona.dart';
import 'package:uni_carona/models/carona.dart';

class _RotasFake extends RotaService {
  final chamadas = <List<LatLng>>[];
  final respostas = <Completer<RotaResultado>>[];
  @override
  Future<RotaResultado> calcularRota(List<LatLng> pontos) {
    chamadas.add(pontos);
    final resposta = Completer<RotaResultado>();
    respostas.add(resposta);
    return resposta.future;
  }
}

void main() {
  testWidgets('ajuste visual na ponte preserva o GPS usado para a rota', (
    tester,
  ) async {
    final service = _RotasFake();
    const gps = LatLng(-21.199865, -50.4);
    const ponte = [LatLng(-21.2, -50.401), LatLng(-21.2, -50.399)];
    final carona = Carona(
      id: 1,
      origem: 'Início',
      destino: 'Fim da ponte',
      destinoLatitude: -21.2,
      destinoLongitude: -50.399,
      dataInicio: DateTime(2026, 10, 28),
      horario: '18:00',
      vagas: 2,
      valor: 0,
      recorrente: false,
      diasSemana: [],
      motorista: 'Motorista',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapaNavegacaoCarona(
            carona: carona,
            localizacaoMotorista: gps,
            precisaoMotorista: 25,
            direcaoMotorista: 90,
            rotaService: service,
          ),
        ),
      ),
    );
    expect(service.chamadas.single.first, gps);
    service.respostas.single.complete(
      RotaResultado(pontos: ponte, distanciaMetros: 200, duracaoSegundos: 10),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final marcador = tester
        .widgetList<MarkerLayer>(find.byType(MarkerLayer))
        .expand((camada) => camada.markers)
        .singleWhere(
          (m) =>
              m.child is Tooltip && (m.child as Tooltip).message == 'Motorista',
        );
    expect(marcador.point.latitude, closeTo(-21.2, 0.0000001));
    expect(service.chamadas.single.first.latitude, gps.latitude);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'falha encerra loading, agrupa recálculos e descarta tela com consulta pendente',
    (tester) async {
      final service = _RotasFake();
      final carona = Carona(
        id: 1,
        origem: 'Origem',
        destino: 'Destino',
        destinoLatitude: -21.1,
        destinoLongitude: -50.3,
        dataInicio: DateTime(2026, 9, 27),
        horario: '18:00',
        vagas: 2,
        valor: 0,
        recorrente: false,
        diasSemana: [],
        motorista: 'Motorista',
      );
      Widget tela(LatLng posicao) => MaterialApp(
        home: Scaffold(
          body: MapaNavegacaoCarona(
            carona: carona,
            localizacaoMotorista: posicao,
            rotaService: service,
          ),
        ),
      );
      await tester.pumpWidget(tela(const LatLng(-21.2, -50.4)));
      await tester.pumpWidget(tela(const LatLng(-21.21, -50.4)));
      expect(service.chamadas, hasLength(1));
      service.respostas.first.completeError(Exception('504'));
      await tester.pump();
      expect(
        find.text('Não foi possível carregar a rota. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump(const Duration(seconds: 14));
      expect(service.chamadas, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(service.chamadas, hasLength(2));
      expect(service.chamadas.last.first, const LatLng(-21.21, -50.4));
      await tester.pumpWidget(const SizedBox());
      service.respostas.last.completeError(Exception('sem conexão'));
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );
}
