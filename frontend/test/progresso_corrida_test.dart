import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uni_carona/mapa/services/progresso_corrida.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/services/progresso_carona_service.dart';

PontoEmbarque ponto(int id, {bool concluido = false}) => PontoEmbarque(
  id: id,
  ordem: id,
  endereco: 'Ponto $id',
  latitude: -21.2,
  longitude: -50.4,
  percorridoEm: concluido ? DateTime(2026, 10, 4) : null,
);
Position posicao(
  int segundos, {
  double precisao = 8,
  double latitude = -21.2,
  double longitude = -50.4,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  accuracy: precisao,
  timestamp: DateTime(2026, 10, 4, 12, 0, segundos),
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _Service extends ProgressoCaronaService {
  List<PontoEmbarque> salvos = [ponto(1), ponto(2)];
  int chamadas = 0;
  bool falhar = false;
  @override
  Future<List<PontoEmbarque>> consultar(int idCarona) async => List.of(salvos);
  @override
  Future<List<PontoEmbarque>> marcar(int idCarona, int idPonto) async {
    chamadas++;
    if (falhar) throw const ErroProgresso('Sem conexão');
    salvos = salvos
        .map((p) => p.id == idPonto ? ponto(idPonto, concluido: true) : p)
        .toList();
    return List.of(salvos);
  }
}

void main() {
  for (final cenario in [
    (
      nome: 'apenas se aproxima do ponto',
      primeira: posicao(0, longitude: -50.4014),
      segunda: posicao(5, longitude: -50.4007),
    ),
    (
      nome: 'passa fora do raio de 30 m',
      primeira: posicao(0, latitude: -21.1995, longitude: -50.4007),
      segunda: posicao(5, latitude: -21.1995, longitude: -50.3993),
    ),
    (
      nome: 'fica muito tempo sem amostra',
      primeira: posicao(0, longitude: -50.4007),
      segunda: posicao(30, longitude: -50.3993),
    ),
    (
      nome: 'recebe um salto muito distante',
      primeira: posicao(0, longitude: -50.403),
      segunda: posicao(5, longitude: -50.397),
    ),
    (
      nome: 'recebe coordenadas fora de ordem',
      primeira: posicao(5, longitude: -50.4007),
      segunda: posicao(0, longitude: -50.3993),
    ),
    (
      nome: 'recebe uma posição imprecisa',
      primeira: posicao(0, longitude: -50.4007),
      segunda: posicao(5, longitude: -50.3993, precisao: 80),
    ),
    (
      nome: 'recebe deslocamento impossível para o intervalo',
      primeira: posicao(0, longitude: -50.4007),
      segunda: posicao(1, longitude: -50.3993),
    ),
  ]) {
    testWidgets('não marca ponto quando ${cenario.nome}', (tester) async {
      final service = _Service();
      final progresso = ProgressoCorrida(7, service: service);
      await progresso.sincronizar();
      progresso.observar(cenario.primeira);
      progresso.observar(cenario.segunda);
      await tester.pump();
      expect(service.chamadas, 0);
      expect(progresso.concluidos, isEmpty);
      progresso.dispose();
    });
  }

  testWidgets('leitura repetida não conta como segunda aproximação', (
    tester,
  ) async {
    final service = _Service();
    final progresso = ProgressoCorrida(7, service: service);
    await progresso.sincronizar();
    progresso.observar(posicao(0));
    progresso.observar(posicao(0));
    await tester.pump();
    expect(service.chamadas, 0);
    progresso.observar(posicao(5));
    await tester.pump();
    expect(service.chamadas, 1);
    progresso.dispose();
  });

  testWidgets('registra passagem pelo ponto entre duas leituras na estrada', (
    tester,
  ) async {
    final service = _Service();
    final progresso = ProgressoCorrida(7, service: service);
    await progresso.sincronizar();
    // As duas amostras estão a cerca de 72 m do ponto, em lados opostos.
    progresso.observar(posicao(0, longitude: -50.4007));
    progresso.observar(posicao(5, longitude: -50.3993));
    await tester.pump();
    expect(service.chamadas, 1);
    expect(progresso.concluidos, {1});
    expect(progresso.proximo?.id, 2);
    progresso.dispose();
  });

  test('recupera os pontos salvos ao reabrir', () async {
    final service = _Service()..salvos = [ponto(1, concluido: true), ponto(2)];
    final progresso = ProgressoCorrida(7, service: service);
    await progresso.sincronizar();
    expect(progresso.concluidos, {1});
    expect(progresso.proximo?.id, 2);
    progresso.dispose();
  });
  testWidgets('exige duas leituras precisas e próximas no tempo', (
    tester,
  ) async {
    final service = _Service();
    final progresso = ProgressoCorrida(7, service: service);
    await progresso.sincronizar();
    progresso.observar(posicao(0));
    progresso.observar(posicao(1, precisao: 80));
    progresso.observar(posicao(2));
    expect(service.chamadas, 0);
    progresso.observar(posicao(3));
    await tester.pump();
    expect(service.chamadas, 1);
    expect(progresso.concluidos, {1});
    progresso.dispose();
  });
  testWidgets(
    'falha não confirma ponto e repete o mesmo envio sem pular etapa',
    (tester) async {
      final service = _Service()..falhar = true;
      final progresso = ProgressoCorrida(7, service: service);
      await progresso.sincronizar();
      progresso.marcarProximo();
      await tester.pump();
      expect(progresso.concluidos, isEmpty);
      expect(progresso.erro, isNotNull);
      progresso.marcarProximo();
      expect(service.chamadas, 1);
      service.falhar = false;
      await tester.pump(const Duration(seconds: 5));
      expect(progresso.concluidos, {1});
      expect(service.chamadas, 2);
      progresso.dispose();
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
