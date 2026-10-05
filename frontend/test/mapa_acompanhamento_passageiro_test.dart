import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/services/rota_service.dart';
import 'package:uni_carona/mapa/widgets/mapa_acompanhamento_passageiro.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';

class _RotasFake extends RotaService {
  final chamadas = <List<LatLng>>[];
  final resposta = Completer<RotaResultado>();

  @override
  Future<RotaResultado> calcularRota(List<LatLng> pontos) {
    chamadas.add(pontos);
    return resposta.future;
  }
}

void main() {
  testWidgets('aguarda progresso e exclui embarque já percorrido da rota', (
    tester,
  ) async {
    final service = _RotasFake();
    final solicitacao = SolicitacaoEnviada(
      id: 1,
      status: 'ACEITA',
      localEmbarque: 'Ponto já percorrido',
      embarqueLatitude: -21.21,
      embarqueLongitude: -50.4,
      motorista: 'Motorista',
      idCarona: 2,
      destino: 'Destino',
      destinoLatitude: -21.1,
      destinoLongitude: -50.3,
      dataInicio: DateTime(2026, 10, 4),
      horario: '18:00',
      valor: 0,
    );
    Widget tela(List<PontoEmbarque>? pontos) => MaterialApp(
      home: Scaffold(
        body: MapaAcompanhamentoPassageiro(
          solicitacao: solicitacao,
          localizacaoMotorista: const LatLng(-21.2, -50.4),
          pontosPercurso: pontos,
          rotaService: service,
        ),
      ),
    );
    await tester.pumpWidget(tela(null));
    expect(service.chamadas, isEmpty);
    await tester.pumpWidget(
      tela([
        PontoEmbarque(
          id: 1,
          endereco: 'Ponto já percorrido',
          latitude: -21.21,
          longitude: -50.4,
          ordem: 1,
          percorridoEm: DateTime(2026, 10, 4, 18),
        ),
        const PontoEmbarque(
          id: 2,
          endereco: 'Próximo ponto',
          latitude: -21.15,
          longitude: -50.35,
          ordem: 2,
        ),
      ]),
    );
    expect(service.chamadas.single, [
      const LatLng(-21.2, -50.4),
      const LatLng(-21.15, -50.35),
      const LatLng(-21.1, -50.3),
    ]);
    await tester.pumpWidget(const SizedBox());
    service.resposta.completeError(Exception('sem conexão'));
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });
}
