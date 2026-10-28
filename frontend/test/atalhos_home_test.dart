import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';

import 'destino_home_test.dart' as fixtures;

class Observador extends NavigatorObserver {
  int aberturas = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) aberturas++;
  }
}

class DestinoLeituraFalha extends DestinoPreferidoService {
  @override
  Future<LocalizacaoSelecionada?> carregar(int idUsuario) async =>
      throw StateError('Falha simulada de leitura');
}

VoidCallback? acao(WidgetTester tester, String texto) {
  if (texto == 'Destino') {
    return tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).onTap;
  }
  return tester
      .widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text(texto),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      )
      .onPressed;
}

http.Response vazio() =>
    http.Response(jsonEncode({'sucesso': true, 'dados': []}), 200);

Future<void> executar(
  Future<void> Function() corpo, {
  Future<http.Response> Function(http.Request)? responder,
}) async {
  try {
    await http.runWithClient(
      corpo,
      () => MockClient(responder ?? (_) async => vazio()),
    );
  } finally {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  }
}

Future<void> abrir(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  Observador observador, {
  DestinoPreferidoService? destino,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [observador],
      home: TelaInicial(
        nomeUsuario: 'Pessoa',
        destinoPreferidoService: destino ?? const DestinoPreferidoService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  for (final par in [
    ('Buscar carona', 'Buscar carona'),
    ('Oferecer carona', 'Oferecer carona'),
    ('Buscar carona', 'Oferecer carona'),
    ('Oferecer carona', 'Buscar carona'),
    ('Ver todas', 'Buscar carona'),
    ('Buscar carona', 'Ver todas'),
    ('Destino', 'Buscar carona'),
    ('Buscar carona', 'Destino'),
    ('Destino', 'Oferecer carona'),
  ]) {
    testWidgets('somente primeira acao abre: ${par.$1} / ${par.$2}', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      final destino = fixtures.DestinoLento();
      await executar(() async {
        await abrir(tester, navigator, observador, destino: destino);
        // Guarda callbacks anteriores ao redesenho para testar a protecao logica.
        final primeira = acao(tester, par.$1)!;
        final segunda = acao(tester, par.$2)!;
        primeira();
        segunda();
        await tester.pump();
        for (final texto in [
          'Buscar carona',
          'Oferecer carona',
          'Ver todas',
          'Destino',
        ]) {
          expect(acao(tester, texto), isNull);
        }
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(observador.aberturas, 0);
        destino.pendente.complete(fixtures.local);
        await tester.pumpAndSettle();
        expect(observador.aberturas, 1);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(acao(tester, 'Buscar carona'), isNotNull);
        expect(acao(tester, 'Oferecer carona'), isNotNull);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final texto in ['Buscar carona', 'Oferecer carona', 'Destino']) {
    testWidgets('timeout libera atalhos e resposta tardia nao abre: $texto', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      final destino = fixtures.DestinoLento();
      await executar(() async {
        await abrir(tester, navigator, observador, destino: destino);
        acao(tester, texto)!();
        await tester.pump();
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();
        expect(find.textContaining('a tempo'), findsOneWidget);
        expect(acao(tester, 'Buscar carona'), isNotNull);
        expect(acao(tester, 'Oferecer carona'), isNotNull);
        expect(observador.aberturas, 0);
        destino.pendente.complete(fixtures.local);
        await tester.pumpAndSettle();
        expect(observador.aberturas, 0);
        acao(tester, texto)!();
        await tester.pumpAndSettle();
        expect(observador.aberturas, 1);
      });
    });

    testWidgets('nao abre sobre outra rota durante a espera: $texto', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      final destino = fixtures.DestinoLento();
      await executar(() async {
        await abrir(tester, navigator, observador, destino: destino);
        acao(tester, texto)!();
        await tester.pump();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Outra tela')),
          ),
        );
        await tester.pumpAndSettle();
        destino.pendente.complete(fixtures.local);
        await tester.pumpAndSettle();
        expect(observador.aberturas, 1);
        expect(find.text('Outra tela'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(acao(tester, 'Buscar carona'), isNotNull);
        expect(acao(tester, 'Oferecer carona'), isNotNull);
      });
    });

    testWidgets('Home removida durante espera nao atualiza estado: $texto', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      final destino = fixtures.DestinoLento();
      await executar(() async {
        await abrir(tester, navigator, observador, destino: destino);
        acao(tester, texto)!();
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        destino.pendente.complete(fixtures.local);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(observador.aberturas, 0);
      });
    });
  }

  testWidgets('voltar da busca libera botoes antes da lista atualizar', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observador = Observador();
    final resposta = Completer<http.Response>();
    var reterAtualizacao = false;
    await executar(
      () async {
        await abrir(tester, navigator, observador);
        acao(tester, 'Buscar carona')!();
        await tester.pumpAndSettle();
        reterAtualizacao = true;
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(acao(tester, 'Buscar carona'), isNotNull);
        expect(acao(tester, 'Oferecer carona'), isNotNull);
        resposta.complete(vazio());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      responder: (request) async {
        if (reterAtualizacao && request.url.path == '/caronas') {
          return resposta.future;
        }
        return vazio();
      },
    );
  });

  testWidgets('falha na leitura preserva aviso e nao bloqueia navegacao', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final observador = Observador();
    await executar(() async {
      await abrir(
        tester,
        navigator,
        observador,
        destino: DestinoLeituraFalha(),
      );
      expect(
        find.text('Não foi possível carregar seu destino salvo'),
        findsOneWidget,
      );
      expect(acao(tester, 'Buscar carona'), isNotNull);
      acao(tester, 'Buscar carona')!();
      await tester.pumpAndSettle();
      expect(observador.aberturas, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(acao(tester, 'Oferecer carona'), isNotNull);
    });
  });

  for (final texto in ['Buscar carona', 'Oferecer carona', 'Destino']) {
    testWidgets('remocao da Home depois de abrir nao atualiza estado: $texto', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      await executar(() async {
        await abrir(tester, navigator, observador);
        acao(tester, texto)!();
        await tester.pumpAndSettle();
        navigator.currentState!.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Nova raiz')),
          ),
          (_) => false,
        );
        await tester.pumpAndSettle();
        expect(find.byType(TelaInicial), findsNothing);
        expect(find.text('Nova raiz'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final criada in [true, false]) {
    testWidgets('voltar da oferta atualiza somente quando criada=$criada', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final observador = Observador();
      var consultas = 0;
      await executar(
        () async {
          await abrir(tester, navigator, observador);
          final iniciais = consultas;
          acao(tester, 'Oferecer carona')!();
          await tester.pumpAndSettle();
          navigator.currentState!.pop(criada ? true : null);
          await tester.pumpAndSettle();
          expect(consultas, criada ? iniciais + 1 : iniciais);
          expect(acao(tester, 'Oferecer carona'), isNotNull);
        },
        responder: (request) async {
          if (request.url.path == '/caronas/minhas') consultas++;
          return vazio();
        },
      );
    });
  }
}
