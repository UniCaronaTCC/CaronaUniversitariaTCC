import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/conversas.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/memoria_conversas.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

import 'conversa_estado_test.dart' show conversaJson;

void main() {
  late MemoriaConversas memoria;
  List<Conversa> lista([String status = 'ATIVA']) => [
    Conversa.fromJson(conversaJson(status)),
  ];
  Map<String, dynamic> ok(List<Conversa> dados) => {
    'sucesso': true,
    'dados': dados,
  };
  Widget tela(
    Future<Map<String, dynamic>> Function() carregar, {
    DateTime Function()? agora,
    int idUsuario = 1,
  }) => MaterialApp(
    home: ConversasTela(
      idUsuario: idUsuario,
      memoria: memoria,
      carregarConversas: carregar,
      agora: agora,
    ),
  );

  setUp(() => memoria = MemoriaConversas());

  testWidgets('sem sessao nao consulta nem fica preso no loading', (
    tester,
  ) async {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
    await tester.pumpWidget(const MaterialApp(home: ConversasTela()));
    await tester.pumpAndSettle();
    expect(find.text('Carregando conversas'), findsNothing);
    expect(
      find.text('Entre novamente para consultar suas conversas.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'fluxo padrao compartilha a memoria e continua consultando a API',
    (tester) async {
      AuthService.tokenUsuarioLogado = 'token-sintetico';
      AuthService.usuarioLogado = {'id': 1};
      MemoriaConversas.compartilhada.limpar();
      addTearDown(SolicitacaoService.pararContadorSolicitacoesPendentes);
      final resposta = Completer<http.Response>();
      var consultas = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(const MaterialApp(home: ConversasTela()));
          await tester.pumpAndSettle();
          expect(find.text('Maria'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(const MaterialApp(home: ConversasTela()));
          await tester.pump();
          expect(find.text('Maria'), findsOneWidget);
          expect(find.text('Carregando conversas'), findsNothing);
          expect(consultas, 2);
          resposta.complete(http.Response('{"sucesso":true,"dados":[]}', 200));
          await tester.pumpAndSettle();
          expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          SolicitacaoService.pararContadorSolicitacoesPendentes();
          await MensagemService.pararContadorMensagensNaoLidas();
        },
        () => MockClient((request) async {
          if (request.url.path == '/conversas') {
            if (++consultas > 1) return resposta.future;
            return http.Response(
              jsonEncode({
                'sucesso': true,
                'dados': [conversaJson('ATIVA')],
              }),
              200,
            );
          }
          return http.Response('{"sucesso":true,"dados":[]}', 200);
        }),
      );
      AuthService.tokenUsuarioLogado = null;
      AuthService.usuarioLogado = null;
    },
  );

  testWidgets('voltar do chat individual mantem a lista enquanto reconsulta', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(SolicitacaoService.pararContadorSolicitacoesPendentes);
    AuthService.usuarioLogado = {'id': 1};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
    final resposta = Completer<Map<String, dynamic>>();
    var consultas = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          tela(
            () =>
                ++consultas == 1 ? Future.value(ok(lista())) : resposta.future,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Maria'));
        await tester.pumpAndSettle();
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(consultas, 2);
        expect(find.text('Maria'), findsOneWidget);
        expect(find.text('Carregando conversas'), findsNothing);
        resposta.complete(ok([]));
        await tester.pumpAndSettle();
        expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        SolicitacaoService.pararContadorSolicitacoesPendentes();
        await MensagemService.pararContadorMensagensNaoLidas();
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({
            'sucesso': true,
            'dados': request.url.path.endsWith('nao-lidas') ? {'total': 0} : [],
            if (request.url.path.endsWith('mensagens'))
              'conversa': conversaJson('ATIVA'),
          }),
          200,
        ),
      ),
    );
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  testWidgets(
    'novo login da mesma conta nao restaura lista da sessao anterior',
    (tester) async {
      await tester.pumpWidget(tela(() async => ok(lista())));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      AuthService.tokenUsuarioLogado = null;
      final resposta = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(tela(() => resposta.future));
      await tester.pump();
      expect(find.text('Maria'), findsNothing);
      expect(find.text('Carregando conversas'), findsOneWidget);
      resposta.complete(ok([]));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('trocar de conta nao mostra conversas da conta anterior', (
    tester,
  ) async {
    await tester.pumpWidget(tela(() async => ok(lista())));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final resposta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(() => resposta.future, idUsuario: 2));
    await tester.pump();
    expect(find.text('Maria'), findsNothing);
    resposta.complete(ok([]));
    await tester.pumpAndSettle();
  });

  testWidgets('reabre mostrando cards antes da rede, sem loading geral', (
    tester,
  ) async {
    await tester.pumpWidget(tela(() async => ok(lista())));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    final resposta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(() => resposta.future));
    await tester.pump();
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Carregando conversas'), findsNothing);
    resposta.complete(ok([]));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsNothing);
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });

  testWidgets('vazio valido tambem reabre sem loading', (tester) async {
    await tester.pumpWidget(tela(() async => ok([])));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    final resposta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(() => resposta.future));
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    expect(find.text('Carregando conversas'), findsNothing);
    resposta.complete(ok(lista()));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
  });

  testWidgets('falha de atualizacao preserva cards e retry funciona', (
    tester,
  ) async {
    var consultas = 0;
    await tester.pumpWidget(
      tela(() async {
        consultas++;
        if (consultas == 2) {
          return {'sucesso': false, 'mensagem': 'Sem internet'};
        }
        return ok(consultas == 3 ? [] : lista());
      }),
    );
    await tester.pumpAndSettle();
    MensagemService.versaoConversas.value++;
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Sem internet'), findsOneWidget);
    await tester.tap(find.byTooltip('Tentar atualizar conversas novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Sem internet'), findsNothing);
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });

  testWidgets('evento com o mesmo total de nao lidas ainda atualiza a lista', (
    tester,
  ) async {
    var consultas = 0;
    final total = MensagemService.totalMensagensNaoLidas.value;
    await tester.pumpWidget(
      tela(() async => ok(++consultas == 1 ? lista() : [])),
    );
    await tester.pumpAndSettle();
    MensagemService.versaoListaConversas.value++;
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(MensagemService.totalMensagensNaoLidas.value, total);
    expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
  });

  testWidgets(
    'evento durante GET exige uma resposta posterior sem sumir com cards',
    (tester) async {
      final antiga = Completer<Map<String, dynamic>>();
      final nova = Completer<Map<String, dynamic>>();
      var consultas = 0;
      await tester.pumpWidget(
        tela(() {
          consultas++;
          return consultas == 1
              ? Future.value(ok(lista()))
              : consultas == 2
              ? antiga.future
              : nova.future;
        }),
      );
      await tester.pumpAndSettle();
      MensagemService.versaoConversas.value++;
      await tester.pump();
      MensagemService.versaoConversas.value++;
      antiga.complete(ok([]));
      await tester.pump();
      expect(find.text('Maria'), findsOneWidget);
      expect(consultas, 3);
      nova.complete(ok([]));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma conversa ainda'), findsOneWidget);
    },
  );

  testWidgets(
    'invalidar sessao remove lista imediatamente e ignora GET antigo',
    (tester) async {
      final resposta = Completer<Map<String, dynamic>>();
      var consultas = 0;
      await tester.pumpWidget(
        tela(
          () => ++consultas == 1 ? Future.value(ok(lista())) : resposta.future,
        ),
      );
      await tester.pumpAndSettle();
      MensagemService.versaoConversas.value++;
      await tester.pump();
      AuthService.tokenUsuarioLogado = null;
      await tester.pump();
      expect(find.text('Maria'), findsNothing);
      resposta.complete(ok(lista()));
      await tester.pumpAndSettle();
      expect(find.text('Maria'), findsNothing);
      expect(find.textContaining('Sua sessão mudou'), findsOneWidget);
    },
  );

  testWidgets('fechar durante GET nao causa setState depois do dispose', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(tela(() => resposta.future));
    await tester.pumpWidget(const SizedBox());
    resposta.complete(ok(lista()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lista restaurada recalcula arquivamento por tempo sem aguardar rede',
    (tester) async {
      var agora = DateTime.utc(2026, 10, 8, 15);
      final encerrada = Conversa.fromJson(
        conversaJson('FINALIZADA')
          ..['encerradaEm'] = agora
              .subtract(const Duration(hours: 23))
              .toIso8601String(),
      );
      await tester.pumpWidget(
        tela(() async => ok([encerrada]), agora: () => agora),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      agora = agora.add(const Duration(hours: 2));
      final resposta = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(tela(() => resposta.future, agora: () => agora));
      await tester.pump();
      expect(find.text('Maria'), findsNothing);
      await tester.tap(find.text('Encerradas'));
      await tester.pump();
      expect(find.text('Maria'), findsOneWidget);
      resposta.complete(ok([encerrada]));
      await tester.pumpAndSettle();
    },
  );
}
