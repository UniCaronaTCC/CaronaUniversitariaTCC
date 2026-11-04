import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/historico_caronas.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';
import 'package:uni_carona/widgets/painel_solicitacoes_carona.dart';

import 'detalhes_carona_solicitacao_test.dart' as fixtures;

http.Response resposta(Object corpo, [int status = 200]) => http.Response(
  jsonEncode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> pedido({String status = 'PENDENTE'}) => {
  'id': 23,
  'status': status,
  'localEmbarque': 'Encontro teste',
  'embarqueLatitude': -21.2,
  'embarqueLongitude': -50.4,
  'passageiro': {'nome': 'Passageiro teste'},
  'carona': {
    'id': 1,
    'destino': 'Campus teste',
    'dataInicio': '2026-11-01',
    'horario': '19:00:00',
    'status': 'ATIVA',
  },
};

Future<void> executar(
  WidgetTester tester,
  Future<void> Function() corpo,
  Future<http.Response> Function(http.Request) responder,
) async {
  try {
    await http.runWithClient(corpo, () => MockClient(responder));
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  }
}

Future<void> abrirPedidos(WidgetTester tester, bool painel) async {
  await tester.pumpWidget(
    MaterialApp(
      home: painel
          ? const Scaffold(
              body: SingleChildScrollView(
                child: PainelSolicitacoesCarona(idCarona: 1),
              ),
            )
          : MinhasCaronasTela(
              carregarRecebidas: () async => {
                'sucesso': true,
                'dados': [SolicitacaoRecebida.fromJson(pedido())],
              },
              carregarEnviadas: () async => {
                'sucesso': true,
                'dados': <SolicitacaoEnviada>[],
              },
            ),
    ),
  );
  await tester.pumpAndSettle();
}

void conferirAviso(WidgetTester tester, bool sucesso) {
  final aviso = tester.widget<AvisoApp>(find.byType(AvisoApp));
  expect(aviso.tipo, sucesso ? TipoAviso.sucesso : TipoAviso.erro);
  final material = tester.widget<Material>(
    find
        .descendant(of: find.byType(AvisoApp), matching: find.byType(Material))
        .first,
  );
  expect(material.color, Color(sucesso ? 0xFF15803D : 0xFFC62828));
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Motorista teste'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  for (final painel in [false, true]) {
    for (final sucesso in [false, true]) {
      for (final aceitar in [false, true]) {
        testWidgets(
          'resposta painel=$painel sucesso=$sucesso aceitar=$aceitar',
          (tester) async {
            var comandos = 0;
            var retornos = 0;
            await executar(
              tester,
              () async {
                await abrirPedidos(tester, painel);
                await tester.ensureVisible(
                  find.text(aceitar ? 'ACEITAR' : 'RECUSAR'),
                );
                await tester.tap(find.text(aceitar ? 'ACEITAR' : 'RECUSAR'));
                await tester.pumpAndSettle();
                conferirAviso(tester, sucesso);
                expect(find.text('Resultado do pedido'), findsOneWidget);
              },
              (request) async {
                if (request.method == 'PATCH') {
                  comandos++;
                  expect(request.url.path, '/solicitacoes/23/status');
                  expect(
                    jsonDecode(request.body)['status'],
                    aceitar ? 'ACEITA' : 'RECUSADA',
                  );
                  return resposta({
                    'mensagem': 'Resultado do pedido',
                  }, sucesso ? 200 : 409);
                }
                if (request.url.path == '/caronas/1/solicitacoes') retornos++;
                return resposta({
                  'sucesso': true,
                  'dados': [
                    if (request.url.path == '/caronas/1/solicitacoes') pedido(),
                  ],
                });
              },
            );
            expect(comandos, 1);
            if (painel) expect(retornos, sucesso ? 2 : 1);
          },
        );
      }

      testWidgets('cancelamento painel=$painel sucesso=$sucesso', (
        tester,
      ) async {
        var comandos = 0;
        await executar(
          tester,
          () async {
            await abrirPedidos(tester, painel);
            final dynamic estado = tester.state(
              find.byType(
                painel ? PainelSolicitacoesCarona : MinhasCaronasTela,
              ),
            );
            final Future<void> operacao = painel
                ? estado.cancelar(
                    SolicitacaoRecebida.fromJson(pedido(status: 'ACEITA')),
                  )
                : estado.cancelar(
                    idSolicitacao: 23,
                    confirmada: true,
                    motorista: true,
                  );
            await tester.pumpAndSettle();
            expect(comandos, 0);
            await tester.tap(find.text('CONFIRMAR CANCELAMENTO'));
            await tester.pumpAndSettle();
            await operacao;
            conferirAviso(tester, sucesso);
            expect(find.text('Resultado do cancelamento'), findsOneWidget);
          },
          (request) async {
            if (request.method == 'PATCH') {
              comandos++;
              expect(request.url.path, '/solicitacoes/23/cancelar');
              return resposta({
                'mensagem': 'Resultado do cancelamento',
              }, sucesso ? 200 : 409);
            }
            return resposta({'sucesso': true, 'dados': []});
          },
        );
        expect(comandos, 1);
      });
    }

    testWidgets('desistir do cancelamento nao envia comando painel=$painel', (
      tester,
    ) async {
      var comandos = 0;
      await executar(
        tester,
        () async {
          await abrirPedidos(tester, painel);
          final dynamic estado = tester.state(
            find.byType(painel ? PainelSolicitacoesCarona : MinhasCaronasTela),
          );
          final Future<void> operacao = painel
              ? estado.cancelar(
                  SolicitacaoRecebida.fromJson(pedido(status: 'ACEITA')),
                )
              : estado.cancelar(
                  idSolicitacao: 23,
                  confirmada: true,
                  motorista: true,
                );
          await tester.pumpAndSettle();
          await tester.tap(find.text('VOLTAR'));
          await tester.pumpAndSettle();
          await operacao;
          expect(find.byType(AvisoApp), findsNothing);
        },
        (request) async {
          if (request.method != 'GET') comandos++;
          return resposta({'sucesso': true, 'dados': []});
        },
      );
      expect(comandos, 0);
    });
  }

  for (final historico in [false, true]) {
    for (final sucesso in [false, true]) {
      testWidgets('avaliacao historico=$historico sucesso=$sucesso', (
        tester,
      ) async {
        var envios = 0;
        var cargas = 0;
        Future<Map<String, dynamic>> carregar() async {
          cargas++;
          return {'sucesso': true, 'dados': []};
        }

        await executar(
          tester,
          () async {
            await tester.pumpWidget(
              MaterialApp(
                home: historico
                    ? HistoricoCaronasTela(
                        carregarOfertas: carregar,
                        carregarPedidos: carregar,
                      )
                    : MinhasCaronasTela(
                        carregarRecebidas: carregar,
                        carregarEnviadas: carregar,
                      ),
              ),
            );
            await tester.pumpAndSettle();
            final dynamic estado = tester.state(
              find.byType(historico ? HistoricoCaronasTela : MinhasCaronasTela),
            );
            final Future<void> operacao = historico
                ? estado.avaliar(
                    SolicitacaoEnviada.fromJson(
                      fixtures.solicitacaoTeste(status: 'ACEITA'),
                    ),
                  )
                : estado.avaliar(23, 'Motorista teste');
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Enviar'),
                  )
                  .onPressed,
              isNull,
            );
            await tester.tap(find.byTooltip('5 estrelas'));
            await tester.pump();
            await tester.tap(find.text('Enviar'));
            await tester.pumpAndSettle();
            await operacao;
            conferirAviso(tester, sucesso);
            expect(cargas, historico && !sucesso ? 2 : 4);
          },
          (request) async {
            if (request.url.path == '/avaliacoes') {
              envios++;
              expect(jsonDecode(request.body), {
                'idSolicitacao': 23,
                'nota': 5,
                'comentario': null,
              });
              return resposta({
                'mensagem': 'Resultado da avaliacao',
              }, sucesso ? 201 : 409);
            }
            return resposta({'sucesso': true, 'dados': []});
          },
        );
        expect(envios, 1);
      });
    }
  }

  testWidgets('aceite com percurso desatualizado oferece somente consulta', (
    tester,
  ) async {
    var comandos = 0;
    var consultas = 0;
    await executar(
      tester,
      () async {
        await tester.pumpWidget(
          MaterialApp(home: DetalhesCaronaTela(carona: fixtures.caronaTeste())),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('ACEITAR'));
        await tester.tap(find.text('ACEITAR'));
        await tester.pumpAndSettle();
        conferirAviso(tester, true);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final aviso = tester.widget<AvisoApp>(find.byType(AvisoApp));
        expect(aviso.tipo, TipoAviso.atencao);
        expect(find.textContaining('foi aceita, mas'), findsOneWidget);
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).duration,
          const Duration(seconds: 8),
        );
        await tester.tap(find.text('ATUALIZAR'));
        await tester.pumpAndSettle();
        expect(comandos, 1);
        expect(consultas, 2);
      },
      (request) async {
        if (request.method == 'PATCH') {
          comandos++;
          return resposta({'mensagem': 'Aceita'});
        }
        if (request.url.path == '/caronas/minhas') {
          consultas++;
          return resposta({'mensagem': 'Consulta indisponivel'}, 503);
        }
        return resposta({
          'sucesso': true,
          'dados': [
            if (request.url.path == '/caronas/1/solicitacoes') pedido(),
          ],
        });
      },
    );
  });

  for (final remover in [false, true]) {
    testWidgets('resposta tardia nao avisa em outra tela remover=$remover', (
      tester,
    ) async {
      final respostaPendente = Completer<http.Response>();
      final navegador = GlobalKey<NavigatorState>();
      var comandos = 0;
      await executar(
        tester,
        () async {
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navegador,
              home: const Scaffold(body: PainelSolicitacoesCarona(idCarona: 1)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('ACEITAR'));
          await tester.pump();
          if (remover) {
            await tester.pumpWidget(
              const MaterialApp(home: Scaffold(body: Text('Outra tela'))),
            );
          } else {
            unawaited(
              navegador.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Outra tela')),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          respostaPendente.complete(resposta({'mensagem': 'Aceita'}));
          await tester.pumpAndSettle();
          expect(find.text('Outra tela'), findsOneWidget);
          expect(find.byType(AvisoApp), findsNothing);
          expect(tester.takeException(), isNull);
        },
        (request) async {
          if (request.method == 'PATCH') {
            comandos++;
            return respostaPendente.future;
          }
          return resposta({
            'sucesso': true,
            'dados': [
              if (request.url.path == '/caronas/1/solicitacoes') pedido(),
            ],
          });
        },
      );
      expect(comandos, 1);
    });
  }

  for (final sucesso in [false, true]) {
    testWidgets(
      'exclusao nos detalhes preserva aviso ao voltar sucesso=$sucesso',
      (tester) async {
        final navegador = GlobalKey<NavigatorState>();
        bool? retorno;
        var exclusoes = 0;
        await executar(
          tester,
          () async {
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navegador,
                home: const Scaffold(body: Text('Lista de caronas')),
              ),
            );
            unawaited(
              navegador.currentState!
                  .push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          DetalhesCaronaTela(carona: fixtures.caronaTeste()),
                    ),
                  )
                  .then((valor) => retorno = valor),
            );
            await tester.pumpAndSettle();
            final dynamic estado = tester.state(
              find.byType(DetalhesCaronaTela),
            );
            final Future<void> operacao = estado.confirmarExclusao();
            await tester.pumpAndSettle();
            expect(exclusoes, 0);
            await tester.tap(find.widgetWithText(FilledButton, 'EXCLUIR'));
            await tester.pumpAndSettle();
            await operacao;
            conferirAviso(tester, sucesso);
            expect(
              find.text('Lista de caronas'),
              sucesso ? findsOneWidget : findsNothing,
            );
            expect(retorno, sucesso ? isTrue : isNull);
          },
          (request) async {
            if (request.method == 'DELETE') {
              exclusoes++;
              return resposta({
                'mensagem': 'Resultado da exclusao',
              }, sucesso ? 200 : 409);
            }
            return resposta({'sucesso': true, 'dados': []});
          },
        );
        expect(exclusoes, 1);
      },
    );

    testWidgets('cancelar oferta na home sucesso=$sucesso', (tester) async {
      var exclusoes = 0;
      await executar(
        tester,
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: TelaInicial(nomeUsuario: 'Teste')),
          );
          await tester.pumpAndSettle();
          final dynamic estado = tester.state(find.byType(TelaInicial));
          final Future<void> operacao = estado.cancelarCaronaPublicada(
            fixtures.caronaTeste(),
          );
          await tester.pumpAndSettle();
          expect(exclusoes, 0);
          await tester.tap(find.text('CANCELAR CARONA'));
          await tester.pumpAndSettle();
          await operacao;
          conferirAviso(tester, sucesso);
        },
        (request) async {
          if (request.method == 'DELETE') {
            exclusoes++;
            expect(request.url.path, '/caronas/1');
            return resposta({
              'mensagem': 'Resultado da exclusao',
            }, sucesso ? 200 : 409);
          }
          return resposta({'sucesso': true, 'dados': []});
        },
      );
      expect(exclusoes, 1);
    });
  }
}
