import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/services/rota_service.dart';
import 'package:uni_carona/mapa/widgets/mapa_navegacao_carona.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/ponto_embarque.dart';

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
  testWidgets(
    'refaz rota e marcadores com os pontos sincronizados, sem ressuscitar parada removida',
    (tester) async {
      final service = _RotasFake();
      const primeiro = PontoEmbarque(
        id: 1,
        ordem: 1,
        endereco: 'Primeiro',
        latitude: -21.19,
        longitude: -50.39,
      );
      const compartilhado = PontoEmbarque(
        id: 2,
        ordem: 2,
        endereco: 'Compartilhado',
        latitude: -21.18,
        longitude: -50.38,
      );
      final carona = Carona(
        id: 1,
        origem: 'Origem',
        destino: 'Destino',
        pontosEmbarque: const [primeiro, compartilhado],
        destinoLatitude: -21.1,
        destinoLongitude: -50.3,
        dataInicio: DateTime(2026, 11, 5),
        horario: '18:00',
        vagas: 2,
        valor: 1,
        recorrente: false,
        diasSemana: const [],
        motorista: 'Motorista',
      );
      Widget tela(List<PontoEmbarque> pontos) => MaterialApp(
        home: Scaffold(
          body: MapaNavegacaoCarona(
            carona: carona,
            pontosPercurso: pontos,
            localizacaoMotorista: const LatLng(-21.2, -50.4),
            rotaService: service,
          ),
        ),
      );
      await tester.pumpWidget(tela(const [primeiro, compartilhado]));
      expect(service.chamadas.single, hasLength(4));
      // A lista mudou enquanto o cálculo anterior ainda estava pendente.
      await tester.pumpWidget(tela(const [compartilhado]));
      service.respostas.first.complete(
        RotaResultado(
          pontos: service.chamadas.first,
          distanciaMetros: 100,
          duracaoSegundos: 10,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(service.chamadas, hasLength(2));
      expect(service.chamadas.last, [
        const LatLng(-21.2, -50.4),
        const LatLng(-21.18, -50.38),
        const LatLng(-21.1, -50.3),
      ]);
      service.respostas.last.complete(
        RotaResultado(
          pontos: service.chamadas.last,
          distanciaMetros: 80,
          duracaoSegundos: 8,
        ),
      );
      await tester.pump();
      final titulos = tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .expand((camada) => camada.markers)
          .map((m) => m.child)
          .whereType<Tooltip>()
          .map((t) => t.message);
      expect(titulos, isNot(contains('Encontro 1')));
      expect(titulos, contains('Encontro 2'));
      // Outra resposta com os mesmos dados não precisa de novo cálculo.
      await tester.pumpWidget(tela(const [compartilhado]));
      await tester.pump(const Duration(seconds: 15));
      expect(service.chamadas, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'avisos da rota continuam acessiveis com pouca altura e fonte ampliada',
    (tester) async {
      final service = _RotasFake();
      final carona = Carona(
        id: 1,
        origem: 'Origem',
        destino: 'Destino',
        destinoLatitude: -21.1,
        destinoLongitude: -50.3,
        dataInicio: DateTime(2026, 11, 1),
        horario: '18:00',
        vagas: 2,
        valor: 0,
        recorrente: false,
        diasSemana: const [],
        motorista: 'Motorista',
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: 80,
                child: MapaNavegacaoCarona(
                  carona: carona,
                  localizacaoMotorista: const LatLng(-21.2, -50.4),
                  rotaService: service,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      service.respostas.single.completeError(Exception('Sem conexão'));
      await tester.pump();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
    },
  );

  testWidgets('mapa estreito com fonte ampliada preserva o GPS na ponte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
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
    expect(
      find.text('flutter_map | © OpenStreetMap contributors'),
      findsOneWidget,
    );
    expect(find.byTooltip('Voltar para a navegação'), findsOneWidget);
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
