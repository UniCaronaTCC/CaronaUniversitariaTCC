import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/filtros_busca_carona.dart';

Map<String, dynamic> carona(int id, {String destino = 'Campus'}) => {
  'idCarona': id,
  'origem': 'Centro',
  'destino': destino,
  'destinoLatitude': -21.2,
  'destinoLongitude': -50.4,
  'dataInicio': '2026-11-01',
  'horario': '19:00:00',
  'vagas': 2,
  'valor': 8,
  'usuario': {'idUsuario': 2, 'nome': 'Motorista teste'},
};

http.Response lista(List<Map<String, dynamic>> dados) =>
    http.Response(jsonEncode({'sucesso': true, 'dados': dados}), 200);

Future<void> executar(
  Future<void> Function() acao,
  http.Client Function() criarCliente,
) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(const Size(390, 844));
  final busca = criarCliente();
  try {
    await http.runWithClient(
      acao,
      () => MockClient((request) async {
        if (request.url.path != '/caronas') return lista([]);
        return busca.get(request.url, headers: request.headers);
      }),
    );
  } finally {
    busca.close();
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    await binding.setSurfaceSize(null);
  }
}

void main() {
  setUp(() => AuthService.tokenUsuarioLogado = 'token-teste');
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  testWidgets(
    'erro inicial nao aparece como nenhuma carona e permite nova tentativa',
    (tester) async {
      var chamadas = 0;
      await executar(
        () async {
          await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
          await tester.pumpAndSettle();
          expect(find.text('Nenhuma carona disponível'), findsNothing);
          expect(find.textContaining('indisponível'), findsOneWidget);
          await tester.ensureVisible(find.text('Tentar novamente'));
          await tester.tap(find.text('Tentar novamente'));
          await tester.pumpAndSettle();
          expect(find.byType(CardCaronaDisponivel), findsOneWidget);
          expect(find.text('Tentar novamente'), findsNothing);
        },
        () => MockClient(
          (_) async =>
              ++chamadas == 1 ? http.Response('HTML', 503) : lista([carona(1)]),
        ),
      );
      expect(chamadas, 2);
    },
  );

  testWidgets('vazio legitimo continua mostrando nenhuma carona', (
    tester,
  ) async {
    await executar(() async {
      await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma carona disponível'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
    }, () => MockClient((_) async => lista([])));
  });

  testWidgets(
    'atualizacao falha mantem cards e nova tentativa substitui resultados',
    (tester) async {
      var chamadas = 0;
      await executar(
        () async {
          await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
                .carona
                .id,
            1,
          );
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(find.text('Não foi possível atualizar'), findsOneWidget);
          expect(find.textContaining('última consulta'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byType(CardCaronaDisponivel),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(
            tester
                .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
                .carona
                .id,
            1,
          );
          await tester.ensureVisible(find.text('Tentar novamente'));
          await tester.tap(find.text('Tentar novamente'));
          await tester.pumpAndSettle();
          expect(find.text('Não foi possível atualizar'), findsNothing);
          expect(
            tester
                .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
                .carona
                .id,
            2,
          );
        },
        () => MockClient((_) async {
          chamadas++;
          return chamadas == 2
              ? http.Response('HTML', 503)
              : lista([carona(chamadas == 1 ? 1 : 2)]);
        }),
      );
    },
  );

  testWidgets('lista vazia valida apos atualizar remove cards antigos', (
    tester,
  ) async {
    var chamadas = 0;
    await executar(
      () async {
        await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
        await tester.pumpAndSettle();
        expect(find.byType(CardCaronaDisponivel), findsOneWidget);
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(find.byType(CardCaronaDisponivel), findsNothing);
        expect(find.text('Nenhuma carona disponível'), findsOneWidget);
      },
      () => MockClient((_) async => lista(++chamadas == 1 ? [carona(1)] : [])),
    );
  });

  testWidgets('atualizacao em andamento mantem cards e compartilha consulta', (
    tester,
  ) async {
    var chamadas = 0;
    final pendente = Completer<http.Response>();
    await executar(
      () async {
        await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
        await tester.pumpAndSettle();
        final atualizar = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh;
        final primeira = atualizar();
        final segunda = atualizar();
        await tester.pump();
        expect(chamadas, 2);
        expect(find.byType(CardCaronaDisponivel), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        pendente.complete(lista([carona(2)]));
        await Future.wait([primeira, segunda]);
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          tester
              .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
              .carona
              .id,
          2,
        );
      },
      () => MockClient(
        (_) => ++chamadas == 1
            ? Future.value(lista([carona(1)]))
            : pendente.future,
      ),
    );
  });

  testWidgets('timeout libera carregamento e oferece nova tentativa', (
    tester,
  ) async {
    await executar(() async {
      await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('demorou'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Nenhuma carona disponível'), findsNothing);
    }, () => MockClient((_) => Completer<http.Response>().future));
  });

  testWidgets('sair da tela durante consulta nao causa setState apos dispose', (
    tester,
  ) async {
    final pendente = Completer<http.Response>();
    await executar(() async {
      await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
      await tester.pumpWidget(const SizedBox());
      pendente.complete(lista([carona(1)]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => pendente.future));
  });

  testWidgets('falha preserva destino inicial e filtros sem consulta extra', (
    tester,
  ) async {
    var chamadas = 0;
    const destino = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Campus',
      endereco: 'Rua teste, 10',
    );
    await executar(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: BuscarCaronaTela(destinoInicial: destino)),
        );
        await tester.pumpAndSettle();
        final filtros = tester.widget<FiltrosBuscaCarona>(
          find.byType(FiltrosBuscaCarona),
        );
        final texto = filtros.destinoController.text;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(filtros.destinoController.text, texto);
        await tester.scrollUntilVisible(
          find.byType(CardCaronaDisponivel),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byType(CardCaronaDisponivel), findsOneWidget);
        filtros.onLimparFiltros();
        await tester.pumpAndSettle();
        expect(chamadas, 2);
        expect(filtros.destinoController.text, isEmpty);
      },
      () => MockClient(
        (_) async =>
            ++chamadas == 1 ? lista([carona(1)]) : http.Response('HTML', 503),
      ),
    );
  });

  testWidgets('resposta invalida apos lista vazia mostra erro e nao vazio', (
    tester,
  ) async {
    var chamadas = 0;
    await executar(
      () async {
        await tester.pumpWidget(const MaterialApp(home: BuscarCaronaTela()));
        await tester.pumpAndSettle();
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(find.text('Nenhuma carona disponível'), findsNothing);
        expect(find.textContaining('resposta inválida'), findsOneWidget);
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
      () => MockClient(
        (_) async => ++chamadas == 1 ? lista([]) : http.Response('{}', 200),
      ),
    );
  });
}
