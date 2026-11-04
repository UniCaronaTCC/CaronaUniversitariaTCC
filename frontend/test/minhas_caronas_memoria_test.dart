import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/home/pagamento_pix.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_solicitacoes.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';

import 'memoria_solicitacoes_test.dart' as fixtures;
import 'avisos_pix_test.dart' show PagamentoControlado, pagamento;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoriaSolicitacoes memoria;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    memoria = MemoriaSolicitacoes();
  });
  tearDown(() async {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Widget tela({
    Future<Map<String, dynamic>> Function()? recebidas,
    Future<Map<String, dynamic>> Function()? enviadas,
    int aba = 0,
    PagamentoControlado? pix,
    GlobalKey<NavigatorState>? navegador,
  }) => MaterialApp(
    navigatorKey: navegador,
    home: MinhasCaronasTela(
      memoria: memoria,
      carregarRecebidas: recebidas ?? () async => fixtures.recebidasOk(),
      carregarEnviadas: enviadas ?? () async => fixtures.enviadasOk(),
      abaInicial: aba,
      pagamentoService: pix,
    ),
  );

  Future<void> limpar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  }

  testWidgets('sem sessao nao consulta nem permanece no loading', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MinhasCaronasTela()));
    await tester.pumpAndSettle();
    expect(find.text('Carregando suas caronas...'), findsNothing);
    expect(find.textContaining('Entre novamente'), findsOneWidget);
    await limpar(tester);
  });

  for (final vazia in [false, true]) {
    testWidgets('reabre lista vazia=$vazia antes da rede e bloqueia acoes', (
      tester,
    ) async {
      await tester.pumpWidget(
        tela(recebidas: () async => fixtures.recebidasOk(vazia: vazia)),
      );
      await tester.pumpAndSettle();
      await limpar(tester);
      final resposta = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(tela(recebidas: () => resposta.future));
      await tester.pump();
      expect(find.text('Carregando suas caronas...'), findsNothing);
      expect(
        find.text(vazia ? 'Nenhuma solicitação recebida' : 'Passageiro'),
        findsOneWidget,
      );
      if (!vazia) {
        expect(
          tester
              .widget<CardSolicitacaoRecebida>(
                find.byType(CardSolicitacaoRecebida),
              )
              .acoesHabilitadas,
          isFalse,
        );
        expect(
          tester
              .widget<ButtonStyleButton>(
                find
                    .ancestor(
                      of: find.text('ACEITAR'),
                      matching: find.byWidgetPredicate(
                        (widget) => widget is ButtonStyleButton,
                      ),
                    )
                    .first,
              )
              .onPressed,
          isNull,
        );
      }
      resposta.complete(fixtures.recebidasOk());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CardSolicitacaoRecebida>(
              find.byType(CardSolicitacaoRecebida),
            )
            .acoesHabilitadas,
        isTrue,
      );
      await limpar(tester);
    });
  }

  testWidgets('falha parcial preserva ambas as listas e retry limpa o erro', (
    tester,
  ) async {
    var consultas = 0;
    await tester.pumpWidget(
      tela(
        recebidas: () async {
          consultas++;
          return consultas == 2
              ? {'sucesso': false, 'mensagem': 'Sem internet'}
              : fixtures.recebidasOk(vazia: consultas == 3);
        },
      ),
    );
    await tester.pumpAndSettle();
    MensagemService.versaoConversas.value++;
    await tester.pumpAndSettle();
    expect(find.text('Passageiro'), findsOneWidget);
    expect(find.text('Sem internet'), findsOneWidget);
    expect(
      tester
          .widget<CardSolicitacaoRecebida>(find.byType(CardSolicitacaoRecebida))
          .acoesHabilitadas,
      isFalse,
    );
    await tester.tap(find.text('Enviadas'));
    await tester.pumpAndSettle();
    expect(find.text('Motorista'), findsOneWidget);
    await tester.tap(find.byTooltip('Tentar atualizar caronas novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Sem internet'), findsNothing);
    expect(find.text('Motorista'), findsOneWidget);
    await tester.tap(find.text('Recebidas'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma solicitação recebida'), findsOneWidget);
    await limpar(tester);
  });

  testWidgets(
    'evento durante GET exige resposta posterior sem esconder os cards',
    (tester) async {
      var consultas = 0;
      final antiga = Completer<Map<String, dynamic>>();
      final nova = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        tela(
          recebidas: () {
            consultas++;
            return consultas == 1
                ? Future.value(fixtures.recebidasOk())
                : consultas == 2
                ? antiga.future
                : nova.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      MensagemService.versaoConversas.value++;
      await tester.pump();
      MensagemService.versaoConversas.value++;
      antiga.complete(fixtures.recebidasOk(vazia: true));
      await tester.pump();
      expect(consultas, 3);
      expect(find.text('Passageiro'), findsOneWidget);
      nova.complete(fixtures.recebidasOk(vazia: true));
      await tester.pumpAndSettle();
      expect(find.text('Passageiro'), findsNothing);
      await limpar(tester);
    },
  );

  testWidgets('sair durante GET remove dados e ignora resposta tardia', (
    tester,
  ) async {
    var consultas = 0;
    final pendente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(
        recebidas: () => ++consultas == 1
            ? Future.value(fixtures.recebidasOk())
            : pendente.future,
      ),
    );
    await tester.pumpAndSettle();
    MensagemService.versaoConversas.value++;
    await tester.pump();
    AuthService.tokenUsuarioLogado = null;
    await tester.pump();
    expect(find.text('Passageiro'), findsNothing);
    pendente.complete(fixtures.recebidasOk());
    await tester.pumpAndSettle();
    expect(find.textContaining('Sua sessão mudou'), findsOneWidget);
    expect(find.text('Passageiro'), findsNothing);
    await limpar(tester);
  });

  testWidgets('dispose durante GET nao provoca setState tardio', (
    tester,
  ) async {
    final pendente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(recebidas: () => pendente.future));
    await limpar(tester);
    pendente.complete(fixtures.recebidasOk());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('acao nao duplica PATCH nem libera botoes antes da reconsulta', (
    tester,
  ) async {
    AuthService.tokenUsuarioLogado = 'token-teste';
    final comando = Completer<http.Response>();
    final leitura = Completer<Map<String, dynamic>>();
    var consultas = 0;
    var comandos = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          tela(
            recebidas: () => ++consultas == 1
                ? Future.value(fixtures.recebidasOk())
                : leitura.future,
          ),
        );
        await tester.pumpAndSettle();
        final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
        final item = SolicitacaoRecebida.fromJson(fixtures.dadosSolicitacao());
        final Future<void> primeira = estado.responder(item, 'ACEITA');
        await estado.responder(item, 'ACEITA');
        await tester.pump();
        expect(comandos, 1);
        comando.complete(http.Response('{"mensagem":"Aceita"}', 200));
        await tester.pump();
        await tester.pump();
        expect(find.text('Passageiro'), findsOneWidget);
        expect(find.text('Carregando suas caronas...'), findsNothing);
        expect(
          tester
              .widget<CardSolicitacaoRecebida>(
                find.byType(CardSolicitacaoRecebida),
              )
              .acoesHabilitadas,
          isFalse,
        );
        leitura.complete(fixtures.recebidasOk(vazia: true));
        await tester.pumpAndSettle();
        await primeira;
        expect(find.text('Passageiro'), findsNothing);
        await limpar(tester);
      },
      () => MockClient((_) {
        comandos++;
        return comando.future;
      }),
    );
  });

  testWidgets(
    'falha apos comando preserva dados mas exige retry antes de repetir',
    (tester) async {
      AuthService.tokenUsuarioLogado = 'token-teste';
      var consultas = 0;
      var comandos = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            tela(
              recebidas: () async => ++consultas == 2
                  ? {'sucesso': false, 'mensagem': 'Falha ao atualizar'}
                  : fixtures.recebidasOk(),
            ),
          );
          await tester.pumpAndSettle();
          final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
          final item = SolicitacaoRecebida.fromJson(
            fixtures.dadosSolicitacao(),
          );
          await estado.responder(item, 'ACEITA');
          await tester.pumpAndSettle();
          expect(find.text('Passageiro'), findsOneWidget);
          expect(find.text('Falha ao atualizar'), findsOneWidget);
          await estado.responder(item, 'ACEITA');
          expect(comandos, 1);
          await tester.tap(
            find.byTooltip('Tentar atualizar caronas novamente'),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CardSolicitacaoRecebida>(
                  find.byType(CardSolicitacaoRecebida),
                )
                .acoesHabilitadas,
            isTrue,
          );
          await limpar(tester);
        },
        () => MockClient((_) async {
          comandos++;
          return http.Response('{}', 200);
        }),
      );
    },
  );

  testWidgets('cancelamento nao envia comando se os dados mudam no dialogo', (
    tester,
  ) async {
    var mudou = false;
    var comandos = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          tela(
            recebidas: () async => {
              'sucesso': true,
              'dados': <SolicitacaoRecebida>[
                SolicitacaoRecebida.fromJson(
                  fixtures.dadosSolicitacao(
                    status: mudou ? 'EXPIRADA' : 'ACEITA',
                  ),
                ),
              ],
            },
          ),
        );
        await tester.pumpAndSettle();
        final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
        final Future<void> acao = estado.cancelar(
          idSolicitacao: 23,
          confirmada: true,
          motorista: true,
        );
        await tester.pumpAndSettle();
        mudou = true;
        MensagemService.versaoConversas.value++;
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR CANCELAMENTO'));
        await tester.pumpAndSettle();
        await acao;
        expect(comandos, 0);
        expect(
          find.textContaining('A solicitação foi atualizada'),
          findsOneWidget,
        );
        await limpar(tester);
      },
      () => MockClient((_) async {
        comandos++;
        return http.Response('{}', 200);
      }),
    );
  });

  testWidgets('logout durante dialogo impede cancelamento', (tester) async {
    var comandos = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(tela());
        await tester.pumpAndSettle();
        final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
        final Future<void> acao = estado.cancelar(
          idSolicitacao: 23,
          confirmada: true,
          motorista: true,
        );
        await tester.pumpAndSettle();
        AuthService.tokenUsuarioLogado = null;
        await tester.pump();
        await tester.tap(find.text('CONFIRMAR CANCELAMENTO'));
        await tester.pumpAndSettle();
        await acao;
        expect(comandos, 0);
        await limpar(tester);
      },
      () => MockClient((_) async {
        comandos++;
        return http.Response('{}', 200);
      }),
    );
  });

  testWidgets('voltar do Pix revalida sem loading geral e retira botao pago', (
    tester,
  ) async {
    var pago = false;
    final navegador = GlobalKey<NavigatorState>();
    final pix = PagamentoControlado()
      ..preparar = () async => {
        'sucesso': true,
        'dados': pagamento(status: 'PAID'),
      };
    final dados = fixtures.dadosSolicitacao(status: 'ACEITA')..['id'] = 10;
    final enviadas = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(
        aba: 1,
        navegador: navegador,
        pix: pix,
        enviadas: () async {
          if (pago) return enviadas.future;
          return {
            'sucesso': true,
            'dados': [SolicitacaoEnviada.fromJson(dados)],
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAGAR COM PIX'));
    await tester.pumpAndSettle();
    expect(find.byType(PagamentoPixTela), findsOneWidget);
    pago = true;
    navegador.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Motorista'), findsOneWidget);
    expect(find.text('Carregando suas caronas...'), findsNothing);
    expect(
      tester
          .widget<CardSolicitacaoEnviada>(find.byType(CardSolicitacaoEnviada))
          .acoesHabilitadas,
      isFalse,
    );
    enviadas.complete({
      'sucesso': true,
      'dados': [
        SolicitacaoEnviada.fromJson({...dados, 'pagamentoConfirmado': true}),
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('PAGAR COM PIX'), findsNothing);
    expect(find.text('CONFIRMADA'), findsOneWidget);
    expect(pix.preparacoes, 1);
    await limpar(tester);
  });

  testWidgets(
    'fluxo real compartilha tela e contador e recebe mudanca com total igual',
    (tester) async {
      AuthService.usuarioLogado = {'id': 1};
      AuthService.tokenUsuarioLogado = 'token-teste';
      var nome = 'Primeiro passageiro';
      var gets = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: MinhasCaronasTela()));
          await tester.pumpAndSettle();
          expect(gets, 2);
          expect(find.text(nome), findsOneWidget);
          final total = SolicitacaoService.totalSolicitacoesPendentes.value;
          nome = 'Outro passageiro';
          await SolicitacaoService.atualizarTotalSolicitacoesPendentes();
          await tester.pumpAndSettle();
          expect(SolicitacaoService.totalSolicitacoesPendentes.value, total);
          expect(find.text('Primeiro passageiro'), findsNothing);
          expect(find.text(nome), findsOneWidget);
          await limpar(tester);
          final pendente = Completer<http.Response>();
          await http.runWithClient(() async {
            await tester.pumpWidget(
              const MaterialApp(home: MinhasCaronasTela()),
            );
            await tester.pump();
            expect(find.text(nome), findsOneWidget);
            expect(find.text('Carregando suas caronas...'), findsNothing);
            pendente.complete(http.Response('{"dados":[]}', 200));
            await tester.pumpAndSettle();
            await limpar(tester);
          }, () => MockClient((_) => pendente.future));
        },
        () => MockClient((request) async {
          gets++;
          final dados = fixtures.dadosSolicitacao()
            ..['passageiro'] = {'nome': nome};
          return http.Response(
            jsonEncode({
              'dados': [if (request.url.path.endsWith('/recebidas')) dados],
            }),
            200,
          );
        }),
      );
    },
  );

  testWidgets('troca de conta nao restaura listas da conta anterior', (
    tester,
  ) async {
    AuthService.usuarioLogado = {'id': 1};
    await tester.pumpWidget(tela());
    await tester.pumpAndSettle();
    await limpar(tester);
    AuthService.usuarioLogado = {'id': 2};
    final pendente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(recebidas: () => pendente.future));
    await tester.pump();
    expect(find.text('Passageiro'), findsNothing);
    pendente.complete(fixtures.recebidasOk(vazia: true));
    await tester.pumpAndSettle();
    await limpar(tester);
  });

  testWidgets('novo login da mesma conta nao restaura listas antigas', (
    tester,
  ) async {
    await tester.pumpWidget(tela());
    await tester.pumpAndSettle();
    await limpar(tester);
    AuthService.tokenUsuarioLogado = null;
    final pendente = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(recebidas: () => pendente.future));
    await tester.pump();
    expect(find.text('Passageiro'), findsNothing);
    pendente.complete(fixtures.recebidasOk(vazia: true));
    await tester.pumpAndSettle();
    await limpar(tester);
  });

  testWidgets('enviadas restauradas bloqueiam Pix sem anunciar preparacao', (
    tester,
  ) async {
    final dados = fixtures.dadosSolicitacao(status: 'ACEITA')..['id'] = 10;
    final pix = PagamentoControlado();
    await tester.pumpWidget(
      tela(
        aba: 1,
        pix: pix,
        enviadas: () async => {
          'sucesso': true,
          'dados': [SolicitacaoEnviada.fromJson(dados)],
        },
      ),
    );
    await tester.pumpAndSettle();
    await limpar(tester);
    final consulta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      tela(aba: 1, pix: pix, enviadas: () => consulta.future),
    );
    await tester.pump();
    expect(find.text('PAGAR COM PIX'), findsOneWidget);
    expect(find.text('PREPARANDO...'), findsNothing);
    final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
    await estado.pagarComPix(SolicitacaoEnviada.fromJson(dados));
    expect(pix.preparacoes, 0);
    consulta.complete({
      'sucesso': true,
      'dados': [SolicitacaoEnviada.fromJson(dados)],
    });
    await tester.pumpAndSettle();
    await limpar(tester);
  });

  testWidgets('sucesso tardio ao preparar Pix nao abre tela sobre outra rota', (
    tester,
  ) async {
    final dados = fixtures.dadosSolicitacao(status: 'ACEITA')..['id'] = 10;
    final navegador = GlobalKey<NavigatorState>();
    final resposta = Completer<Map<String, dynamic>>();
    final pix = PagamentoControlado()..preparar = () => resposta.future;
    await tester.pumpWidget(
      tela(
        aba: 1,
        pix: pix,
        navegador: navegador,
        enviadas: () async => {
          'sucesso': true,
          'dados': [SolicitacaoEnviada.fromJson(dados)],
        },
      ),
    );
    await tester.pumpAndSettle();
    final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
    final Future<void> acao = estado.pagarComPix(
      SolicitacaoEnviada.fromJson(dados),
    );
    await tester.pump();
    unawaited(
      navegador.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    resposta.complete({'sucesso': true, 'dados': pagamento(status: 'PAID')});
    await tester.pumpAndSettle();
    await acao;
    expect(find.text('Outra tela'), findsOneWidget);
    expect(find.byType(PagamentoPixTela), findsNothing);
    await limpar(tester);
  });

  testWidgets('aviso com cards cabe em tela estreita e fonte ampliada', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var falha = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.8),
          ),
          child: MinhasCaronasTela(
            memoria: memoria,
            carregarRecebidas: () async => falha
                ? {
                    'sucesso': false,
                    'mensagem':
                        'Não foi possível atualizar as solicitações. Confira sua conexão e tente novamente.',
                  }
                : fixtures.recebidasOk(),
            carregarEnviadas: () async => fixtures.enviadasOk(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    falha = true;
    MensagemService.versaoConversas.value++;
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Tentar atualizar caronas novamente'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await limpar(tester);
  });
}
