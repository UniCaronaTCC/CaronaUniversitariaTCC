import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';

import 'atalhos_home_test.dart' as fixtures;
import 'destino_home_test.dart' as destinos;
import 'home_cards_test.dart' as dados;

const destino = LocalizacaoSelecionada(
  ponto: LatLng(-21.235275, -50.4060626),
  nome: 'Campus escolhido',
  endereco: 'Rodovia, 3821',
);
const aviso = 'Nenhuma carona para o destino selecionado.';

Map<String, dynamic> viagem(
  int id, {
  bool corresponde = false,
  String horario = '19:00:00',
}) => {
  ...dados.dadosCarona(id),
  'destino': corresponde ? 'Campus escolhido' : 'Outro campus $id',
  'destinoCidade': 'Aracatuba',
  'destinoLatitude': corresponde ? destino.ponto.latitude : -21.2,
  'destinoLongitude': corresponde ? destino.ponto.longitude : -50.4,
  'horario': horario,
};

List<int> ids(WidgetTester tester, {bool home = true}) => tester
    .widgetList<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
    .where((card) => !home || card.visualHome)
    .map((card) => card.carona.id)
    .toList();

Future<void> abrir(
  WidgetTester tester, {
  DestinoPreferidoService? service,
  NavigatorObserver? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [?observer],
      home: TelaInicial(
        nomeUsuario: 'Pessoa',
        destinoPreferidoService: service ?? const DestinoPreferidoService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> verTodas(WidgetTester tester) async {
  final botao = find.byKey(const ValueKey('ver-todas-disponiveis'));
  await tester.ensureVisible(botao);
  await tester.pumpAndSettle();
  await tester.tap(botao);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
    await const DestinoPreferidoService().salvar(7, destino);
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  for (final quantidade in [1, 2, 4]) {
    testWidgets(
      '$quantidade correspondentes nao sao misturadas com outros destinos',
      (tester) async {
        await fixtures.executar(
          () async {
            await abrir(tester);
            expect(find.text('Caronas disponíveis'), findsOneWidget);
            expect(find.text('Outros destinos'), findsNothing);
            expect(find.text(aviso), findsNothing);
            expect(ids(tester), [
              for (var id = 10; id < 10 + quantidade && id < 13; id++) id,
            ]);
          },
          responder: (request) async => request.url.path == '/caronas'
              ? dados.lista([
                  viagem(50),
                  for (var id = 10; id < 10 + quantidade; id++)
                    viagem(id, corresponde: true),
                ])
              : dados.lista([]),
        );
      },
    );
  }

  testWidgets(
    'sem correspondencias mostra alternativas, limite de tres e ordem por horario',
    (tester) async {
      var consultas = 0;
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Outros destinos'), findsOneWidget);
          expect(find.text('Caronas disponíveis'), findsNothing);
          expect(find.text(aviso), findsOneWidget);
          expect(ids(tester), [11, 12, 10]);
          expect(consultas, 1);
          expect(
            (await const DestinoPreferidoService().carregar(7))?.toJson(),
            destino.toJson(),
          );
        },
        responder: (request) async {
          if (request.url.path != '/caronas') return dados.lista([]);
          consultas++;
          return dados.lista([
            viagem(10, horario: '19:00'),
            viagem(11, horario: '17:00'),
            viagem(12, horario: '18:00'),
            viagem(13, horario: '20:00'),
          ]);
        },
      );
    },
  );

  testWidgets(
    'alternativas mantem a prioridade da cidade atual sem esconder as demais',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          final dynamic estado = tester.state(find.byType(TelaInicial));
          estado.cidadeAtual = 'Aracatuba';
          await estado.carregarConteudo();
          await tester.pumpAndSettle();
          expect(ids(tester), [11, 10]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([
                {
                  ...viagem(10, horario: '17:00'),
                  'origem': 'Sao Paulo',
                  'origemCidade': 'Sao Paulo',
                  'destino': 'Campus SP',
                  'destinoCidade': 'Sao Paulo',
                },
                viagem(11, horario: '19:00'),
              ])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'sem destino salvo permanece lista normal e nao mostra aviso de alternativas',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Caronas disponíveis'), findsOneWidget);
          expect(find.text('Outros destinos'), findsNothing);
          expect(find.text(aviso), findsNothing);
          expect(ids(tester), [10]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10)])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'lista vazia continua vazia sem sugerir alternativas inexistentes',
    (tester) async {
      await fixtures.executar(() async {
        await abrir(tester);
        expect(find.text('Nenhuma carona disponível'), findsOneWidget);
        expect(find.text('Outros destinos'), findsNothing);
        expect(find.text(aviso), findsNothing);
        expect(ids(tester), isEmpty);
      });
    },
  );

  testWidgets('alternativas nao aparecem como resultado de erro HTTP', (
    tester,
  ) async {
    await fixtures.executar(
      () async {
        await abrir(tester);
        expect(find.text('Tentar novamente'), findsOneWidget);
        expect(find.text('Outros destinos'), findsNothing);
        expect(find.text(aviso), findsNothing);
        expect(ids(tester), isEmpty);
      },
      responder: (request) async => request.url.path == '/caronas'
          ? http.Response('indisponivel', 503)
          : dados.lista([]),
    );
  });

  testWidgets(
    'Ver todas nas alternativas abre busca sem destino, sem alterar preferencia',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          await verTodas(tester);
          final busca = tester.widget<BuscarCaronaTela>(
            find.byType(BuscarCaronaTela),
          );
          expect(busca.destinoInicial, isNull);
          expect(ids(tester, home: false), [10, 11, 12, 13]);
          expect(
            (await const DestinoPreferidoService().carregar(7))?.toJson(),
            destino.toJson(),
          );
          Navigator.of(tester.element(find.byType(BuscarCaronaTela))).pop();
          await tester.pumpAndSettle();
          expect(find.text('Outros destinos'), findsOneWidget);
          expect(
            tester
                .widget<CardDestinoHome>(find.byType(CardDestinoHome))
                .destino,
            destino.descricaoCompleta,
          );
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([for (var id = 10; id <= 13; id++) viagem(id)])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'Buscar carona continua com destino salvo mesmo quando Home exibe alternativas',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Outros destinos'), findsOneWidget);
          await tester.tap(find.text('Buscar carona'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
                .destinoInicial
                ?.toJson(),
            destino.toJson(),
          );
          expect(ids(tester, home: false), isEmpty);
          expect(
            find.text('Nenhuma carona corresponde aos filtros'),
            findsOneWidget,
          );
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10)])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'Ver todas com correspondencias preserva filtro normal na busca',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          await verTodas(tester);
          expect(
            tester
                .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
                .destinoInicial
                ?.toJson(),
            destino.toJson(),
          );
          expect(ids(tester, home: false), [10]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10, corresponde: true), viagem(11)])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'suas proximas caronas continuam separadas e sem duplicar a secao de alternativas',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Suas próximas caronas'), findsOneWidget);
          expect(find.text('Outros destinos'), findsOneWidget);
          expect(ids(tester), [10]);
          expect(ids(tester, home: false), [99, 10]);
        },
        responder: (request) async {
          if (request.url.path == '/caronas') return dados.lista([viagem(10)]);
          if (request.url.path == '/caronas/minhas') {
            return dados.lista([dados.dadosCarona(99, motorista: 7)]);
          }
          return dados.lista([]);
        },
      );
    },
  );

  testWidgets('selecionar alternativa abre os detalhes da carona correta', (
    tester,
  ) async {
    await fixtures.executar(
      () async {
        await abrir(tester);
        final card = find.byKey(const ValueKey('card-carona-10'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DetalhesCaronaTela>(find.byType(DetalhesCaronaTela))
              .carona
              .destino,
          'Outro campus 10',
        );
        expect(
          (await const DestinoPreferidoService().carregar(7))?.toJson(),
          destino.toJson(),
        );
      },
      responder: (request) async => request.url.path == '/caronas'
          ? dados.lista([viagem(10)])
          : dados.lista([]),
    );
  });

  testWidgets(
    'destino proximo com nome diferente continua sendo correspondencia',
    (tester) async {
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Caronas disponíveis'), findsOneWidget);
          expect(find.text('Outros destinos'), findsNothing);
          expect(ids(tester), [10]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([
                {
                  ...viagem(10),
                  'destinoLatitude': destino.ponto.latitude + 0.0001,
                  'destinoLongitude': destino.ponto.longitude,
                },
                viagem(11),
              ])
            : dados.lista([]),
      );
    },
  );

  testWidgets(
    'clique duplo em Ver todas das alternativas abre apenas uma busca',
    (tester) async {
      final observer = fixtures.Observador();
      await fixtures.executar(
        () async {
          await abrir(tester, observer: observer);
          final callback = tester
              .widget<TextButton>(
                find.byKey(const ValueKey('ver-todas-disponiveis')),
              )
              .onPressed!;
          callback();
          callback();
          await tester.pumpAndSettle();
          expect(observer.aberturas, 1);
          expect(
            tester
                .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
                .destinoInicial,
            isNull,
          );
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10)])
            : dados.lista([]),
      );
    },
  );

  testWidgets('erro depois de atualizar nao e disfarçado como alternativas', (
    tester,
  ) async {
    var erro = false;
    await fixtures.executar(
      () async {
        await abrir(tester);
        expect(find.text('Outros destinos'), findsOneWidget);
        erro = true;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(find.text('Outros destinos'), findsNothing);
        expect(find.text(aviso), findsNothing);
        expect(find.text('Tentar novamente'), findsOneWidget);
        erro = false;
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pumpAndSettle();
        expect(find.text('Outros destinos'), findsOneWidget);
        expect(ids(tester), [10]);
      },
      responder: (request) async => request.url.path == '/caronas'
          ? erro
                ? http.Response('indisponivel', 503)
                : dados.lista([viagem(10)])
          : dados.lista([]),
    );
  });

  testWidgets(
    'refresh troca alternativas por correspondencias e depois volta sem misturar',
    (tester) async {
      var corresponde = false;
      await fixtures.executar(
        () async {
          await abrir(tester);
          expect(find.text('Outros destinos'), findsOneWidget);
          corresponde = true;
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(find.text('Caronas disponíveis'), findsOneWidget);
          expect(find.text('Outros destinos'), findsNothing);
          expect(ids(tester), [10]);
          corresponde = false;
          await tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
          await tester.pumpAndSettle();
          expect(find.text('Outros destinos'), findsOneWidget);
          expect(ids(tester), [10, 11]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10, corresponde: corresponde), viagem(11)])
            : dados.lista([]),
      );
    },
  );

  testWidgets('trocar destino atualiza secao sem apagar a nova preferencia', (
    tester,
  ) async {
    const novo = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Outro campus 10',
      endereco: 'Rua A, 10',
    );
    await fixtures.executar(
      () async {
        await abrir(tester);
        expect(find.text('Outros destinos'), findsOneWidget);
        await tester.tap(find.byType(CardDestinoHome));
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byType(SelecionarDestinoTela)),
        ).pop(novo);
        await tester.pumpAndSettle();
        expect(find.text('Outros destinos'), findsNothing);
        expect(find.text('Caronas disponíveis'), findsOneWidget);
        expect(ids(tester), [10]);
        expect(
          (await const DestinoPreferidoService().carregar(7))?.toJson(),
          novo.toJson(),
        );
      },
      responder: (request) async => request.url.path == '/caronas'
          ? dados.lista([viagem(10)])
          : dados.lista([]),
    );
  });

  testWidgets(
    'restauracao lenta do destino nao mostra aviso prematuro de alternativas',
    (tester) async {
      final lento = destinos.DestinoLento();
      await fixtures.executar(
        () async {
          await abrir(tester, service: lento);
          expect(find.text('Outros destinos'), findsNothing);
          lento.pendente.complete(destino);
          await tester.pumpAndSettle();
          expect(find.text('Outros destinos'), findsOneWidget);
          expect(ids(tester), [10]);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10)])
            : dados.lista([]),
      );
    },
  );

  for (final largura in [320.0, 390.0]) {
    testWidgets('alternativas cabem em $largura com fonte ampliada', (
      tester,
    ) async {
      tester.view.physicalSize = Size(largura, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await fixtures.executar(
        () async {
          await abrir(tester);
          await tester.ensureVisible(find.text('Outros destinos'));
          await tester.pumpAndSettle();
          expect(find.text(aviso), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        responder: (request) async => request.url.path == '/caronas'
            ? dados.lista([viagem(10)])
            : dados.lista([]),
      );
    });
  }
}
