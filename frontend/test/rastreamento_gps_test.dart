import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uni_carona/mapa/services/localizacao_service.dart';
import 'package:uni_carona/mapa/services/rastreamento_gps.dart';

class _GpsFake extends LocalizacaoService {
  final stream = StreamController<Position>.broadcast();
  @override
  Future<Stream<Position>> acompanharLocalizacao() async => stream.stream;
}

Position posicao({double precisao = 8, DateTime? data}) => Position(
  latitude: -21.2,
  longitude: -50.4,
  timestamp: data ?? DateTime.now(),
  accuracy: precisao,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets('GPS impreciso se recupera sem perder a assinatura', (
    tester,
  ) async {
    final service = _GpsFake();
    final recebidas = <Position>[];
    final gps = RastreamentoGps(service: service, onPosicao: recebidas.add);
    final inicio = gps.iniciar();
    await tester.pump();
    await inicio;
    service.stream.add(posicao(precisao: 100));
    await tester.pump();
    expect(gps.precisaAtencao, isTrue);
    expect(recebidas, isEmpty);
    service.stream.add(posicao());
    await tester.pump();
    expect(gps.precisaAtencao, isFalse);
    expect(recebidas, hasLength(1));
    await tester.pump(const Duration(seconds: 21));
    expect(gps.mensagem, contains('Sem leitura recente'));
    gps.dispose();
    await service.stream.close();
  });

  testWidgets(
    'rejeita posições antigas e não duplica o stream ao tentar novamente',
    (tester) async {
      final service = _GpsFake();
      final recebidas = <Position>[];
      final gps = RastreamentoGps(service: service, onPosicao: recebidas.add);
      final inicio = gps.iniciar();
      await tester.pump();
      await inicio;
      service.stream.add(
        posicao(data: DateTime.now().subtract(const Duration(minutes: 1))),
      );
      await tester.pump();
      expect(recebidas, isEmpty);
      service.stream.addError(Exception('GPS desativado'));
      await tester.pump();
      expect(gps.mensagem, 'GPS desativado');
      // O cancelamento do stream deve terminar antes da nova assinatura.
      await tester.runAsync(gps.iniciar);
      await tester.pump();

      service.stream.add(posicao());
      await tester.pump();
      expect(recebidas, hasLength(1));
      gps.dispose();
      await tester.pump(const Duration(seconds: 30));
      await service.stream.close();
      expect(tester.takeException(), isNull);
    },
  );
}
