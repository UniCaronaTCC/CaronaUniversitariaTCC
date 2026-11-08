import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/avaliar_passageiros.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';

SolicitacaoRecebida passageiro({
  int id = 10,
  int idCarona = 20,
  String status = 'ACEITA',
  String statusCarona = 'FINALIZADA',
  bool podeAvaliar = true,
  bool avaliada = false,
}) => SolicitacaoRecebida(
  id: id,
  idCarona: idCarona,
  passageiro: 'Passageiro $id',
  status: status,
  statusCarona: statusCarona,
  localEmbarque: 'Ponto de teste',
  embarqueLatitude: -21.2,
  embarqueLongitude: -50.4,
  destino: 'Campus',
  dataInicio: DateTime(2026, 11, 8),
  horario: '12:00:00',
  podeAvaliar: podeAvaliar,
  avaliada: avaliada,
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  Future<void> montar(
    WidgetTester tester, {
    CarregarPassageirosAvaliacao? carregar,
    EnviarAvaliacaoPassageiro? enviar,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AvaliarPassageirosTela(
          idCarona: 20,
          carregarPassageiros:
              carregar ??
              (_) async => {
                'sucesso': true,
                'dados': [passageiro()],
              },
          enviarAvaliacao: enviar,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.ensureVisible(find.text('AVALIAR').first);
    await tester.tap(find.text('AVALIAR').first);
    await tester.pumpAndSettle();
  }

  Future<void> enviarNota(WidgetTester tester) async {
    await tester.tap(find.byTooltip('5 estrelas'));
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'envia a nota para a participação e atualiza sem permitir repetição',
    (tester) async {
      var avaliada = false;
      var consultas = 0;
      Map<String, dynamic>? enviado;
      await montar(
        tester,
        carregar: (idCarona) async {
          expect(idCarona, 20);
          consultas++;
          return {
            'sucesso': true,
            'dados': [passageiro(avaliada: avaliada, podeAvaliar: !avaliada)],
          };
        },
        enviar: ({required idSolicitacao, required nota, comentario}) async {
          enviado = {
            'idSolicitacao': idSolicitacao,
            'nota': nota,
            'comentario': comentario,
          };
          avaliada = true;
          return {'sucesso': true};
        },
      );
      await abrirDialogo(tester);
      expect(find.text('Avaliar Passageiro 10'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField), 'Pontual');
      await enviarNota(tester);
      expect(enviado, {
        'idSolicitacao': 10,
        'nota': 5,
        'comentario': 'Pontual',
      });
      expect(consultas, 2);
      expect(find.text('Avaliação enviada'), findsWidgets);
      expect(find.text('AVALIAR'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mantém o botão para tentar novamente quando o envio falha', (
    tester,
  ) async {
    var envios = 0;
    await montar(
      tester,
      enviar: ({required idSolicitacao, required nota, comentario}) async {
        envios++;
        return {'sucesso': false, 'mensagem': 'Falha de teste no envio'};
      },
    );
    await abrirDialogo(tester);
    await enviarNota(tester);
    expect(envios, 1);
    expect(find.text('Falha de teste no envio'), findsOneWidget);
    expect(find.text('AVALIAR'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelar o diálogo não envia avaliação', (tester) async {
    var envios = 0;
    await montar(
      tester,
      enviar: ({required idSolicitacao, required nota, comentario}) async {
        envios++;
        return {'sucesso': true};
      },
    );
    await abrirDialogo(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(envios, 0);
    expect(find.text('AVALIAR'), findsOneWidget);
  });

  for (final status in [
    'PENDENTE',
    'RECUSADA',
    'EXPIRADA',
    'CANCELADA_PASSAGEIRO',
    'CANCELADA_MOTORISTA',
  ]) {
    testWidgets('não permite avaliar quem está $status', (tester) async {
      await montar(
        tester,
        carregar: (_) async => {
          'sucesso': true,
          'dados': [passageiro(status: status)],
        },
      );
      expect(find.text('AVALIAR'), findsNothing);
      expect(find.text('Passageiro 10'), findsNothing);
      expect(
        find.textContaining('Nenhum passageiro disponível'),
        findsOneWidget,
      );
    });
  }

  for (final status in [
    'ATIVA',
    'LOTADA',
    'EM_ANDAMENTO',
    'CANCELADA',
    'EXPIRADA',
    'ENCERRADA_POR_TEMPO',
  ]) {
    testWidgets('não oferece avaliação em carona $status', (tester) async {
      await montar(
        tester,
        carregar: (_) async => {
          'sucesso': true,
          'dados': [passageiro(statusCarona: status)],
        },
      );
      expect(find.text('AVALIAR'), findsNothing);
      expect(find.text('Passageiro 10'), findsNothing);
    });
  }

  testWidgets('omite passageiros de outra carona e participações inelegíveis', (
    tester,
  ) async {
    await montar(
      tester,
      carregar: (_) async => {
        'sucesso': true,
        'dados': [
          passageiro(idCarona: 99),
          passageiro(id: 11, podeAvaliar: false),
        ],
      },
    );
    expect(find.text('AVALIAR'), findsNothing);
    expect(find.text('Passageiro 10'), findsNothing);
    expect(find.text('Passageiro 11'), findsNothing);
  });

  testWidgets('identifica o passageiro já avaliado sem oferecer novo envio', (
    tester,
  ) async {
    await montar(
      tester,
      carregar: (_) async => {
        'sucesso': true,
        'dados': [passageiro(avaliada: true, podeAvaliar: false)],
      },
    );
    expect(find.text('Passageiro 10'), findsOneWidget);
    expect(find.text('Avaliação enviada'), findsOneWidget);
    expect(find.text('AVALIAR'), findsNothing);
  });

  testWidgets('falha de consulta oferece nova tentativa', (tester) async {
    var consultas = 0;
    await montar(
      tester,
      carregar: (_) async {
        consultas++;
        return consultas == 1
            ? {'sucesso': false, 'mensagem': 'Sem conexão de teste'}
            : {
                'sucesso': true,
                'dados': [passageiro()],
              };
      },
    );
    expect(find.text('Sem conexão de teste'), findsOneWidget);
    expect(find.text('AVALIAR'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.text('AVALIAR'), findsOneWidget);
  });

  testWidgets(
    'bloqueia outros envios enquanto uma avaliação está sendo enviada',
    (tester) async {
      final resposta = Completer<Map<String, dynamic>>();
      var envios = 0;
      await montar(
        tester,
        carregar: (_) async => {
          'sucesso': true,
          'dados': [passageiro(), passageiro(id: 11)],
        },
        enviar: ({required idSolicitacao, required nota, comentario}) {
          envios++;
          return resposta.future;
        },
      );
      await abrirDialogo(tester);
      await tester.tap(find.byTooltip('5 estrelas'));
      await tester.pump();
      await tester.tap(find.text('Enviar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(envios, 1);
      final botoes = tester.widgetList<ElevatedButton>(
        find.byWidgetPredicate((widget) => widget is ElevatedButton),
      );
      expect(botoes, hasLength(2));
      expect(botoes.every((botao) => botao.onPressed == null), isTrue);
      resposta.complete({'sucesso': false});
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'consulta a rota da carona e envia pela API existente com o usuário autenticado',
    (tester) async {
      AuthService.usuarioLogado = {'id': 2};
      AuthService.tokenUsuarioLogado = 'token-sintetico-teste';
      var avaliada = false;
      var envios = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: AvaliarPassageirosTela(idCarona: 20)),
          );
          await tester.pumpAndSettle();
          await abrirDialogo(tester);
          await enviarNota(tester);
          expect(envios, 1);
          expect(find.text('AVALIAR'), findsNothing);
          expect(find.text('Avaliação enviada'), findsWidgets);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          expect(
            request.headers['Authorization'],
            'Bearer token-sintetico-teste',
          );
          if (request.method == 'POST') {
            expect(request.url.path, '/avaliacoes');
            expect(jsonDecode(request.body), {
              'idSolicitacao': 10,
              'nota': 5,
              'comentario': null,
            });
            envios++;
            avaliada = true;
            return http.Response(jsonEncode({'sucesso': true}), 201);
          }
          expect(request.url.path, '/caronas/20/solicitacoes');
          return http.Response(
            jsonEncode({
              'sucesso': true,
              'dados': [
                {
                  'id': 10,
                  'status': 'ACEITA',
                  'avaliada': avaliada,
                  'podeAvaliar': !avaliada,
                  'localEmbarque': 'Ponto',
                  'embarqueLatitude': -21.2,
                  'embarqueLongitude': -50.4,
                  'passageiro': {'nome': 'Passageiro 10'},
                  'carona': {
                    'id': 20,
                    'status': 'FINALIZADA',
                    'destino': 'Campus',
                    'dataInicio': '2026-11-08',
                    'horario': '12:00:00',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
    },
  );
}
