import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uni_carona/home/corrida_em_andamento.dart';
import 'package:uni_carona/home/recorrencias.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/recorrencia_carona.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

import 'avisos_caronas_solicitacoes_test.dart' as avisos;
import 'encerramento_corrida_test.dart' as fixtures;

const dadosFinalizados = {
  'id': 1,
  'idMotorista': 7,
  'origem': 'Centro',
  'destino': 'Campus',
  'dataInicio': '2026-11-01',
  'horario': '19:00:00',
  'vagas': 2,
  'valor': 5,
  'status': 'FINALIZADA',
};

RecorrenciaCarona recorrencia(bool ativa) => RecorrenciaCarona.fromJson({
  'idRecorrencia': 7,
  'ativa': ativa,
  'dados': dadosFinalizados,
});

Future<void> executar(
  WidgetTester tester,
  Future<void> Function() corpo,
  Future<http.Response> Function(http.Request) responder,
) => avisos.executar(tester, corpo, (request) async {
  // Estes cenarios isolam os avisos do carregamento do mapa e do GPS real.
  if (request.url.path.endsWith('/progresso')) {
    return avisos.resposta({'mensagem': 'Mapa indisponivel no teste'}, 400);
  }
  return responder(request);
});

Future<void> abrirCorrida(
  WidgetTester tester,
  GlobalKey<NavigatorState> navegador, {
  Future<Map<String, dynamic>> Function(int)? carregarEstado,
  void Function(Carona?)? aoVoltar,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navegador,
      home: const Scaffold(body: Text('Detalhes anteriores')),
    ),
  );
  unawaited(
    navegador.currentState!
        .push<Carona>(
          MaterialPageRoute<Carona>(
            builder: (_) => CorridaEmAndamentoTela(
              carona: fixtures.carona('EM_ANDAMENTO'),
              carregarEstado:
                  carregarEstado ??
                  (_) async => {
                    'sucesso': true,
                    'dados': fixtures.carona('EM_ANDAMENTO'),
                  },
            ),
          ),
        )
        .then((valor) => aoVoltar?.call(valor)),
  );
  await tester.pumpAndSettle();
}

Future<void> confirmarFim(WidgetTester tester) async {
  await tester.tap(find.text('FINALIZAR'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'FINALIZAR'));
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

  for (final mensagem in [null, 'Corrida encerrada pelo motorista']) {
    testWidgets('finalizacao verde sobrevive ao retorno mensagem=$mensagem', (
      tester,
    ) async {
      final navegador = GlobalKey<NavigatorState>();
      Carona? retorno;
      var comandos = 0;
      await executar(
        tester,
        () async {
          await abrirCorrida(
            tester,
            navegador,
            aoVoltar: (carona) => retorno = carona,
          );
          await confirmarFim(tester);
          await tester.pumpAndSettle();
          avisos.conferirAviso(tester, true);
          expect(
            find.text(mensagem ?? 'Corrida finalizada com sucesso'),
            findsOneWidget,
          );
          expect(find.text('Detalhes anteriores'), findsOneWidget);
          expect(retorno?.status, 'FINALIZADA');
        },
        (request) async {
          if (request.method == 'PATCH') {
            comandos++;
            expect(request.url.path, '/caronas/1/finalizar');
            return avisos.resposta({
              'dados': dadosFinalizados,
              'mensagem': ?mensagem,
            });
          }
          return avisos.resposta({'dados': []});
        },
      );
      expect(comandos, 1);
    });
  }

  for (final invalida in [false, true]) {
    testWidgets('falha de finalizacao nao mostra sucesso invalida=$invalida', (
      tester,
    ) async {
      final navegador = GlobalKey<NavigatorState>();
      var consultas = 0;
      var comandos = 0;
      await executar(
        tester,
        () async {
          await abrirCorrida(
            tester,
            navegador,
            carregarEstado: (_) async {
              consultas++;
              return {
                'sucesso': true,
                'dados': fixtures.carona('EM_ANDAMENTO'),
              };
            },
          );
          await confirmarFim(tester);
          await tester.pumpAndSettle();
          avisos.conferirAviso(tester, false);
          expect(find.text('FINALIZAR'), findsOneWidget);
          expect(find.text('Detalhes anteriores'), findsNothing);
          expect(consultas, 2);
        },
        (request) async {
          if (request.method == 'PATCH') {
            comandos++;
            return invalida
                ? avisos.resposta({'dados': null})
                : avisos.resposta({
                    'mensagem': 'Nao foi possivel finalizar',
                  }, 409);
          }
          return avisos.resposta({'dados': []});
        },
      );
      expect(comandos, 1);
    });
  }

  testWidgets(
    'erro de resposta ainda reconcilia corrida encerrada no servidor',
    (tester) async {
      final navegador = GlobalKey<NavigatorState>();
      var consultas = 0;
      await executar(
        tester,
        () async {
          await abrirCorrida(
            tester,
            navegador,
            carregarEstado: (_) async => {
              'sucesso': true,
              'dados': fixtures.carona(
                ++consultas == 1 ? 'EM_ANDAMENTO' : 'FINALIZADA',
              ),
            },
          );
          await confirmarFim(tester);
          await tester.pumpAndSettle();
          avisos.conferirAviso(tester, false);
          expect(find.text('Esta corrida foi encerrada'), findsOneWidget);
          expect(find.text('FINALIZAR'), findsNothing);
          expect(consultas, 2);
        },
        (request) async => request.method == 'PATCH'
            ? avisos.resposta({'mensagem': 'Resposta indisponivel'}, 503)
            : avisos.resposta({'dados': []}),
      );
    },
  );

  testWidgets('desistir da finalizacao nao envia PATCH nem aviso', (
    tester,
  ) async {
    var comandos = 0;
    await executar(
      tester,
      () async {
        await abrirCorrida(tester, GlobalKey<NavigatorState>());
        await tester.tap(find.text('FINALIZAR'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CANCELAR'));
        await tester.pumpAndSettle();
        expect(find.byType(AvisoApp), findsNothing);
        expect(find.text('FINALIZAR'), findsOneWidget);
      },
      (request) async {
        if (request.method == 'PATCH') comandos++;
        return avisos.resposta({'dados': []});
      },
    );
    expect(comandos, 0);
  });

  for (final remover in [false, true]) {
    for (final sucesso in [false, true]) {
      testWidgets('finalizacao atrasada remover=$remover sucesso=$sucesso', (
        tester,
      ) async {
        final navegador = GlobalKey<NavigatorState>();
        final pendente = Completer<void>();
        var comandos = 0;
        await executar(
          tester,
          () async {
            await abrirCorrida(tester, navegador);
            await confirmarFim(tester);
            await tester.pump();
            expect(find.text('FINALIZANDO...'), findsOneWidget);
            expect(
              tester
                  .widget<ButtonStyleButton>(
                    find
                        .ancestor(
                          of: find.text('FINALIZANDO...'),
                          matching: find.byWidgetPredicate(
                            (widget) => widget is ButtonStyleButton,
                          ),
                        )
                        .first,
                  )
                  .onPressed,
              isNull,
            );
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
            pendente.complete();
            await tester.pumpAndSettle();
            expect(find.text('Outra tela'), findsOneWidget);
            expect(find.byType(AvisoApp), findsNothing);
            if (!remover) {
              navegador.currentState!.pop();
              await tester.pumpAndSettle();
              expect(
                find.text('Esta corrida foi encerrada'),
                sucesso ? findsOneWidget : findsNothing,
              );
              expect(
                find.text('FINALIZAR'),
                sucesso ? findsNothing : findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          },
          (request) async {
            if (request.method == 'PATCH') {
              comandos++;
              await pendente.future;
              return sucesso
                  ? avisos.resposta({'dados': dadosFinalizados})
                  : avisos.resposta({'mensagem': 'Falha simulada'}, 409);
            }
            return avisos.resposta({'dados': []});
          },
        );
        expect(comandos, 1);
      });
    }
  }

  for (final ativaInicial in [false, true]) {
    testWidgets(
      'recorrencia falha vermelha e nova tentativa ativa=$ativaInicial',
      (tester) async {
        var ativa = ativaInicial;
        var tentativas = 0;
        var cargas = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: RecorrenciasTela(
              carregar: () async {
                cargas++;
                return [recorrencia(ativa)];
              },
              alterarEstado: (id, valor) async {
                expect(id, 7);
                tentativas++;
                if (tentativas == 1) throw StateError('Falha simulada');
                ativa = valor;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(ativaInicial ? 'PAUSAR' : 'RETOMAR'));
        await tester.pumpAndSettle();
        avisos.conferirAviso(tester, false);
        expect(ativa, ativaInicial);
        expect(cargas, 1);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ativaInicial ? 'PAUSAR' : 'RETOMAR'));
        await tester.pumpAndSettle();
        expect(ativa, !ativaInicial);
        expect(cargas, 2);
        expect(tentativas, 2);
        expect(find.byType(AvisoApp), findsNothing);
      },
    );
  }

  for (final remover in [false, true]) {
    testWidgets(
      'recorrencia com erro tardio nao avisa fora da tela remover=$remover',
      (tester) async {
        final navegador = GlobalKey<NavigatorState>();
        final pendente = Completer<void>();
        var comandos = 0;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navegador,
            home: RecorrenciasTela(
              carregar: () async => [recorrencia(true)],
              alterarEstado: (_, _) async {
                comandos++;
                await pendente.future;
                throw StateError('Falha simulada');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('PAUSAR'));
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
        pendente.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AvisoApp), findsNothing);
        expect(find.text('Outra tela'), findsOneWidget);
        expect(comandos, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
