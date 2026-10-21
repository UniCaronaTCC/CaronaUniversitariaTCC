import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/screens/mapa_screen.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/mapa/widgets/barra_pesquisa_endereco.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

class _EnderecoPendente extends EnderecoService {
  final resposta = Completer<LocalizacaoSelecionada?>();
  @override
  Future<LocalizacaoSelecionada?> buscarLocalizacaoPorCoordenadas(
    double latitude,
    double longitude,
  ) => resposta.future;
}

void main() {
  const canal = MethodChannel('flutter.baseflow.com/geolocator');
  TestWidgetsFlutterBinding.ensureInitialized();
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() {
    mensageiro.setMockMethodCallHandler(canal, null);
  });

  testWidgets(
    'endereco atrasado do GPS nao substitui um encontro escolhido na pesquisa',
    (tester) async {
      final enderecos = _EnderecoPendente();
      mensageiro.setMockMethodCallHandler(canal, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return true;
          case 'checkPermission':
            return 2;
          case 'getCurrentPosition':
            return {
              'latitude': -22.0,
              'longitude': -51.0,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'accuracy': 5.0,
              'altitude': 0.0,
              'heading': 0.0,
              'speed': 0.0,
              'speed_accuracy': 0.0,
            };
          default:
            return null;
        }
      });
      await http.runWithClient(
        () async {
          try {
            await tester.pumpWidget(
              MaterialApp(home: TesteMapa(enderecoService: enderecos)),
            );
            for (var i = 0; i < 4; i++) {
              await tester.pump();
            }
            const manual = LocalizacaoSelecionada(
              ponto: LatLng(-21.2, -50.4),
              endereco: 'Rua manual, 100',
            );
            tester
                .widget<BarraPesquisaEndereco>(
                  find.byType(BarraPesquisaEndereco),
                )
                .onSelecionado(manual);
            await tester.pumpAndSettle();
            expect(find.text('Rua manual, 100'), findsOneWidget);
            enderecos.resposta.complete(
              const LocalizacaoSelecionada(
                ponto: LatLng(-22, -51),
                endereco: 'Endereco anterior do GPS',
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Rua manual, 100'), findsOneWidget);
            expect(find.text('Endereco anterior do GPS'), findsNothing);
          } finally {
            await tester.pumpWidget(const SizedBox());
            SolicitacaoService.pararContadorSolicitacoesPendentes();
            await MensagemService.pararContadorMensagensNaoLidas();
          }
        },
        () => MockClient(
          (_) async => http.Response.bytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
            200,
            headers: {'content-type': 'image/png'},
          ),
        ),
      );
    },
  );

  for (final situacao in ['desativado', 'negado', 'lento']) {
    testWidgets('mapa permite escolher encontro manualmente com GPS $situacao', (
      tester,
    ) async {
      final pendente = Completer<Map<String, dynamic>>();
      var chamadasPosicao = 0;
      mensageiro.setMockMethodCallHandler(canal, (call) async {
        switch (call.method) {
          case 'isLocationServiceEnabled':
            return situacao != 'desativado';
          case 'checkPermission':
          case 'requestPermission':
            return situacao == 'negado' ? 0 : 2;
          case 'getCurrentPosition':
            chamadasPosicao++;
            return pendente.future;
          default:
            return null;
        }
      });
      await http.runWithClient(
        () async {
          try {
            await tester.pumpWidget(
              const MaterialApp(home: TesteMapa(titulo: 'Ponto de encontro')),
            );
            for (var i = 0; i < 4; i++) {
              await tester.pump();
            }
            if (situacao == 'lento') {
              expect(chamadasPosicao, 1);
              await tester.pump(const Duration(seconds: 9));
            }
            await tester.pumpAndSettle();
            expect(find.byType(BarraPesquisaEndereco), findsOneWidget);
            const local = LocalizacaoSelecionada(
              ponto: LatLng(-21.2, -50.4),
              endereco: 'Rua manual, 100',
            );
            tester
                .widget<BarraPesquisaEndereco>(
                  find.byType(BarraPesquisaEndereco),
                )
                .onSelecionado(local);
            await tester.pumpAndSettle();
            expect(find.text('Rua manual, 100'), findsOneWidget);
            if (situacao == 'lento') {
              pendente.complete({
                'latitude': -22.0,
                'longitude': -51.0,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
                'accuracy': 5.0,
                'altitude': 0.0,
                'heading': 0.0,
                'speed': 0.0,
                'speed_accuracy': 0.0,
              });
              await tester.pumpAndSettle();
              expect(find.text('Rua manual, 100'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            SolicitacaoService.pararContadorSolicitacoesPendentes();
            await MensagemService.pararContadorMensagensNaoLidas();
          }
        },
        () => MockClient(
          (req) async => req.url.host == 'tile.openstreetmap.org'
              ? http.Response.bytes(
                  base64Decode(
                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                  ),
                  200,
                  headers: {'content-type': 'image/png'},
                )
              : http.Response('{"sucesso":true,"dados":[]}', 200),
        ),
      );
    });
  }
}
