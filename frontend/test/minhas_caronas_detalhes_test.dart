import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_solicitacoes.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';

import 'memoria_solicitacoes_test.dart' as fixtures;

Carona viagem({int id = 10, int motorista = 2, String status = 'ATIVA'}) =>
    Carona(
      id: id,
      origem: 'Centro',
      destino: 'Campus',
      dataInicio: DateTime(2026, 11, 6),
      horario: '19:00:00',
      vagas: 2,
      valor: 5,
      recorrente: false,
      diasSemana: const [],
      idMotorista: motorista,
      motorista: 'Motorista',
      veiculoModelo: 'Onix',
      veiculoCor: 'Branco',
      status: status,
    );

Map<String, dynamic> ok([Carona? carona]) => {
  'sucesso': true,
  'dados': carona ?? viagem(),
};

void testar(String nome, Future<void> Function(WidgetTester) executar) {
  testWidgets(nome, (tester) async {
    await http.runWithClient(
      () async {
        try {
          await executar(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          SolicitacaoService.pararContadorSolicitacoesPendentes();
          await MensagemService.pararContadorMensagensNaoLidas();
        }
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({
            'sucesso': true,
            'dados': request.url.path.endsWith('/nao-lidas')
                ? {'total': 0}
                : [fixtures.dadosSolicitacao()],
          }),
          200,
        ),
      ),
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoriaSolicitacoes memoria;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-teste';
    memoria = MemoriaSolicitacoes();
  });
  tearDown(() async {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Future<void> abrir(
    WidgetTester tester, {
    int aba = 0,
    Future<Map<String, dynamic>> Function(int)? carregar,
    CarregarSolicitacoes? recebidas,
    GlobalKey<NavigatorState>? navegador,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navegador,
        home: MinhasCaronasTela(
          abaInicial: aba,
          memoria: memoria,
          carregarRecebidas: recebidas ?? () async => fixtures.recebidasOk(),
          carregarEnviadas: () async => fixtures.enviadasOk(),
          carregarCarona: carregar ?? (_) async => ok(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final aba in [0, 1]) {
    testar('aba=$aba consulta endpoint real do servico antes de navegar', (
      tester,
    ) async {
      var consultas = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: MinhasCaronasTela(
                memoria: memoria,
                abaInicial: aba,
                carregarRecebidas: () async => fixtures.recebidasOk(),
                carregarEnviadas: () async => fixtures.enviadasOk(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(aba == 0 ? 'Passageiro' : 'Motorista'));
          await tester.pumpAndSettle();
          final detalhes = tester.widget<DetalhesCaronaTela>(
            find.byType(DetalhesCaronaTela),
          );
          expect(detalhes.carona.id, 10);
          expect(detalhes.carona.veiculoModelo, 'Onix');
          expect(consultas, 1);
        },
        () => MockClient((request) async {
          if (request.url.path == '/caronas/10') {
            consultas++;
            expect(request.method, 'GET');
            expect(request.headers['Authorization'], 'Bearer token-teste');
            return http.Response(
              jsonEncode({
                'sucesso': true,
                'dados': {
                  'idCarona': 10,
                  'dataInicio': '2026-11-06',
                  'destino': 'Campus',
                  'horario': '19:00:00',
                  'usuario': {
                    'idUsuario': aba == 0 ? 1 : 2,
                    'nome': 'Motorista',
                    'veiculo': {'modelo': 'Onix'},
                  },
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'sucesso': true,
              'dados': request.url.path.endsWith('/nao-lidas')
                  ? {'total': 0}
                  : [fixtures.dadosSolicitacao()],
            }),
            200,
          );
        }),
      );
    });
    for (final status in ['ATIVA', 'FINALIZADA', 'CANCELADA']) {
      testar('aba=$aba abre a carona atual em consulta: $status', (
        tester,
      ) async {
        final carona = viagem(motorista: aba == 0 ? 1 : 2, status: status);
        var consultas = 0;
        var listas = 0;
        await abrir(
          tester,
          aba: aba,
          recebidas: () async {
            listas++;
            return fixtures.recebidasOk();
          },
          carregar: (id) async {
            consultas++;
            expect(id, 10);
            return ok(carona);
          },
        );
        await tester.tap(find.text(aba == 0 ? 'Passageiro' : 'Motorista'));
        await tester.pumpAndSettle();
        final detalhes = tester.widget<DetalhesCaronaTela>(
          find.byType(DetalhesCaronaTela),
        );
        expect(detalhes.carona, same(carona));
        expect(detalhes.somenteConsulta, isTrue);
        expect(detalhes.permitirSolicitacao, isFalse);
        expect(detalhes.indiceNavegacaoOrigem, 2);
        expect(find.text('Detalhes da carona'), findsOneWidget);
        expect(find.text('SOLICITAR VAGA'), findsNothing);
        expect(find.text('EDITAR'), findsNothing);
        expect(find.text('EXCLUIR'), findsNothing);
        expect(find.text('INICIAR CORRIDA'), findsNothing);
        expect(
          tester
              .widget<BottomNavigationBar>(
                find.byType(BottomNavigationBar).last,
              )
              .currentIndex,
          2,
        );
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(
          find.text(aba == 0 ? 'Passageiro' : 'Motorista'),
          findsOneWidget,
        );
        expect(find.text('Carregando suas caronas...'), findsNothing);
        expect(consultas, 1);
        expect(listas, 2);
      });
    }
  }

  testar('toques rapidos nao duplicam consulta nem disparam pagamento', (
    tester,
  ) async {
    final pendente = Completer<Map<String, dynamic>>();
    var consultas = 0;
    await abrir(
      tester,
      aba: 1,
      carregar: (_) {
        consultas++;
        return pendente.future;
      },
    );
    await tester.tap(find.text('Motorista'));
    await tester.pump();
    await tester.tap(find.text('Motorista'));
    final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
    await estado.abrirDetalhes(23, 10);
    expect(consultas, 1);
    expect(
      tester
          .widget<CardSolicitacaoEnviada>(find.byType(CardSolicitacaoEnviada))
          .abrindoDetalhes,
      isTrue,
    );
    expect(
      tester
          .widget<CardSolicitacaoEnviada>(find.byType(CardSolicitacaoEnviada))
          .processando,
      isFalse,
    );
    expect(find.text('PREPARANDO...'), findsNothing);
    pendente.complete(ok());
    await tester.pumpAndSettle();
    expect(find.byType(DetalhesCaronaTela), findsOneWidget);
  });

  for (final caso in ['offline', 'excecao', 'id', 'formato']) {
    testar('falha $caso preserva lista e permite nova tentativa', (
      tester,
    ) async {
      var tentativas = 0;
      await abrir(
        tester,
        carregar: (_) async {
          if (++tentativas > 1) return ok();
          if (caso == 'excecao') throw StateError('offline');
          if (caso == 'id') return ok(viagem(id: 99));
          if (caso == 'formato') return {'sucesso': true, 'dados': {}};
          return {'sucesso': false, 'mensagem': 'Carona indisponivel'};
        },
      );
      await tester.tap(find.text('Passageiro'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalhesCaronaTela), findsNothing);
      expect(find.text('Passageiro'), findsOneWidget);
      expect(
        tester
            .widget<CardSolicitacaoRecebida>(
              find.byType(CardSolicitacaoRecebida),
            )
            .abrindoDetalhes,
        isFalse,
      );
      await tester.tap(find.text('Passageiro'));
      await tester.pumpAndSettle();
      expect(tentativas, 2);
      expect(find.byType(DetalhesCaronaTela), findsOneWidget);
    });
  }

  testar('timeout libera o card e resposta tardia nao abre detalhes', (
    tester,
  ) async {
    final pendente = Completer<Map<String, dynamic>>();
    await abrir(tester, carregar: (_) => pendente.future);
    await tester.tap(find.text('Passageiro'));
    await tester.pump(const Duration(seconds: 26));
    await tester.pumpAndSettle();
    expect(find.byType(DetalhesCaronaTela), findsNothing);
    expect(
      tester
          .widget<CardSolicitacaoRecebida>(find.byType(CardSolicitacaoRecebida))
          .abrindoDetalhes,
      isFalse,
    );
    pendente.complete(ok());
    await tester.pumpAndSettle();
    expect(find.byType(DetalhesCaronaTela), findsNothing);
  });

  for (final trocarConta in [false, true]) {
    testar(
      'invalidar sessao trocarConta=$trocarConta impede navegacao tardia',
      (tester) async {
        final pendente = Completer<Map<String, dynamic>>();
        await abrir(tester, carregar: (_) => pendente.future);
        await tester.tap(find.text('Passageiro'));
        await tester.pump();
        AuthService.tokenUsuarioLogado = null;
        AuthService.usuarioLogado = {'id': trocarConta ? 2 : 1};
        pendente.complete(ok());
        await tester.pumpAndSettle();
        expect(find.byType(DetalhesCaronaTela), findsNothing);
        expect(find.text('Passageiro'), findsNothing);
      },
    );
  }

  for (final descartar in [false, true]) {
    testar('sair da tela descartar=$descartar nao redireciona depois', (
      tester,
    ) async {
      final pendente = Completer<Map<String, dynamic>>();
      final navegador = GlobalKey<NavigatorState>();
      await abrir(
        tester,
        navegador: navegador,
        carregar: (_) => pendente.future,
      );
      await tester.tap(find.text('Passageiro'));
      await tester.pump();
      if (descartar) {
        await tester.pumpWidget(const SizedBox());
      } else {
        unawaited(
          navegador.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Outra tela')),
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 3),
        );
      }
      pendente.complete(ok());
      await tester.pumpAndSettle();
      expect(find.byType(DetalhesCaronaTela), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testar(
    'retorno mantem cards e encerra indicador de detalhes antes da revalidacao',
    (tester) async {
      var consultas = 0;
      final pendente = Completer<Map<String, dynamic>>();
      await abrir(
        tester,
        recebidas: () => ++consultas == 1
            ? Future.value(fixtures.recebidasOk())
            : pendente.future,
      );
      await tester.tap(find.text('Passageiro'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Passageiro'), findsOneWidget);
      expect(find.text('Carregando suas caronas...'), findsNothing);
      expect(
        tester
            .widget<CardSolicitacaoRecebida>(
              find.byType(CardSolicitacaoRecebida),
            )
            .abrindoDetalhes,
        isFalse,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pendente.complete(fixtures.recebidasOk());
      await tester.pumpAndSettle();
    },
  );

  testar('consulta de detalhes nao depende da revalidacao da lista', (
    tester,
  ) async {
    final perfil = (1, AuthService.versaoSessao);
    await memoria.atualizar(
      perfil,
      recebidas: () async => fixtures.recebidasOk(),
      enviadas: () async => fixtures.enviadasOk(),
    );
    final pendente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: MinhasCaronasTela(
          memoria: memoria,
          carregarRecebidas: () => pendente.future,
          carregarEnviadas: () async => fixtures.enviadasOk(),
          carregarCarona: (_) async => ok(),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<CardSolicitacaoRecebida>(find.byType(CardSolicitacaoRecebida))
          .acoesHabilitadas,
      isFalse,
    );
    await tester.tap(find.text('Passageiro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DetalhesCaronaTela), findsOneWidget);
    pendente.complete(fixtures.recebidasOk());
    await tester.pumpAndSettle();
  });

  for (final recebida in [true, false]) {
    for (final modo in ['semAcao', 'bloqueado', 'carregando']) {
      testar('card recebida=$recebida nao navega em $modo', (tester) async {
        var consultas = 0;
        final VoidCallback? abrirDetalhes = modo == 'semAcao'
            ? null
            : () => consultas++;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: recebida
                    ? CardSolicitacaoRecebida(
                        solicitacao: SolicitacaoRecebida.fromJson(
                          fixtures.dadosSolicitacao(),
                        ),
                        processando: false,
                        onAceitar: () {},
                        onRecusar: () {},
                        onAbrirDetalhes: abrirDetalhes,
                        detalhesHabilitados: modo != 'bloqueado',
                        abrindoDetalhes: modo == 'carregando',
                      )
                    : CardSolicitacaoEnviada(
                        solicitacao: SolicitacaoEnviada.fromJson(
                          fixtures.dadosSolicitacao(),
                        ),
                        onAbrirDetalhes: abrirDetalhes,
                        detalhesHabilitados: modo != 'bloqueado',
                        abrindoDetalhes: modo == 'carregando',
                      ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text(recebida ? 'Passageiro' : 'Motorista'));
        expect(consultas, 0);
        expect(
          find.byIcon(Icons.chevron_right),
          modo == 'bloqueado' ? findsOneWidget : findsNothing,
        );
      });
    }
    testar('card recebida=$recebida separa botoes e area clicavel', (
      tester,
    ) async {
      var detalhes = 0;
      var acoes = 0;
      Widget card(bool habilitar) => recebida
          ? CardSolicitacaoRecebida(
              solicitacao: SolicitacaoRecebida.fromJson(
                fixtures.dadosSolicitacao(),
              ),
              processando: false,
              acoesHabilitadas: habilitar,
              onAbrirDetalhes: () => detalhes++,
              onAceitar: () => acoes++,
              onRecusar: () => acoes++,
            )
          : CardSolicitacaoEnviada(
              solicitacao: SolicitacaoEnviada.fromJson(
                fixtures.dadosSolicitacao(status: 'ACEITA'),
              ),
              acoesHabilitadas: habilitar,
              onAbrirDetalhes: () => detalhes++,
              onPagarPix: () => acoes++,
              onCancelar: () => acoes++,
            );
      Future<void> montar(bool habilitar) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: card(habilitar))),
          ),
        );
        await tester.pumpAndSettle();
      }

      await montar(true);
      for (final texto
          in recebida
              ? ['ACEITAR', 'RECUSAR']
              : ['PAGAR COM PIX', 'CANCELAR PARTICIPAÇÃO']) {
        await tester.ensureVisible(find.text(texto));
        await tester.tap(find.text(texto));
      }
      expect(acoes, 2);
      expect(detalhes, 0);
      await montar(false);
      await tester.ensureVisible(
        find.text(recebida ? 'ACEITAR' : 'PAGAR COM PIX'),
      );
      await tester.tap(find.text(recebida ? 'ACEITAR' : 'PAGAR COM PIX'));
      expect(acoes, 2);
      expect(detalhes, 0);
      await tester.ensureVisible(
        find.text(recebida ? 'Passageiro' : 'Motorista'),
      );
      await tester.tap(find.text(recebida ? 'Passageiro' : 'Motorista'));
      expect(detalhes, 1);
    });
  }

  for (final recebida in [true, false]) {
    testar(
      'card recebida=$recebida mantem opcionalidade e cabe com fonte ampliada',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: recebida
                    ? CardSolicitacaoRecebida(
                        solicitacao: SolicitacaoRecebida.fromJson(
                          fixtures.dadosSolicitacao(),
                        ),
                        processando: false,
                        onAceitar: () {},
                        onRecusar: () {},
                        onAbrirDetalhes: () {},
                      )
                    : CardSolicitacaoEnviada(
                        solicitacao: SolicitacaoEnviada.fromJson(
                          fixtures.dadosSolicitacao(),
                        ),
                        onAbrirDetalhes: () {},
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      },
    );
  }
}
