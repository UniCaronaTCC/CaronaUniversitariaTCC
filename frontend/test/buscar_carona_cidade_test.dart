import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/cidade_pesquisa_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/utils/data_hora_utils.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/filtros_busca_carona.dart';

import 'buscar_carona_erros_test.dart' as base;
import 'campo_destino_campus_test.dart'
    show CatalogoTeste, EnderecosTeste, campi, cidadeA, referenciaA;
import 'cidade_pesquisa_fluxo_test.dart'
    show CidadesTeste, PreferenciaTeste, birigui;

const campusBirigui = CampusDestino(
  idCampus: 10,
  idInstituicao: 10,
  nome: 'Faculdade de Birigui',
  campus: 'Centro',
  cidade: birigui,
  ponto: LatLng(-21.28, -50.34),
);

class CampusBuscaTeste extends CatalogoTeste {
  int consultasGps = 0;

  @override
  Future<CidadeCampus?> identificarCidade() {
    consultasGps++;
    return super.identificarCidade();
  }
}

Finder get campoDestino => find.descendant(
  of: find.byType(CampoDestinoCampus),
  matching: find.byType(TextField),
);

FiltrosBuscaCarona filtros(WidgetTester tester) =>
    tester.widget<FiltrosBuscaCarona>(find.byType(FiltrosBuscaCarona));

List<int> resultados(WidgetTester tester) => tester
    .widgetList<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
    .map((card) => card.carona.id)
    .toList();

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> abrirCidades(WidgetTester tester) async {
  await tocar(tester, campoDestino);
  await tocar(tester, find.byTooltip('Alterar cidade'));
}

Future<void> escolherCidade(WidgetTester tester, CidadeCampus cidade) async {
  await abrirCidades(tester);
  await tester.enterText(
    find.byKey(const ValueKey('pesquisa-cidade')),
    cidade.cidade,
  );
  await tester.pump();
  await tocar(
    tester,
    find.byKey(ValueKey('cidade-${cidade.cidade}-${cidade.uf}')),
  );
}

void main() {
  const preferencia = CidadePesquisaService();
  late CampusBuscaTeste catalogo;
  late EnderecosTeste enderecos;
  late int consultasCaronas;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-teste';
    consultasCaronas = 0;
    catalogo = CampusBuscaTeste();
    catalogo.resposta = (cidade) async => cidade.mesmaCidade(cidadeA)
        ? campi
        : cidade.mesmaCidade(birigui)
        ? [campusBirigui]
        : [];
    enderecos = EnderecosTeste();
  });

  tearDown(() => AuthService.tokenUsuarioLogado = null);

  Future<void> executar(Future<void> Function() acao) => base.executar(
    acao,
    () => MockClient((_) async {
      consultasCaronas++;
      return base.lista([
        {
          ...base.carona(1),
          'origemCidade': cidadeA.cidade,
          'destinoCidade': cidadeA.cidade,
          'dataInicio': DataHoraUtils.formatarDataBackend(DateTime.now()),
          'horario': '18:00:00',
        },
        {
          ...base.carona(2),
          'origemCidade': birigui.cidade,
          'destinoCidade': birigui.cidade,
          'destinoLatitude': -21.28,
          'destinoLongitude': -50.34,
          'dataInicio': DataHoraUtils.formatarDataBackend(DateTime.now()),
          'horario': '18:10:00',
        },
      ]);
    }),
  );

  Future<void> montar(
    WidgetTester tester, {
    int id = 7,
    bool comReferencia = true,
    bool comDestino = false,
    CidadePesquisaService service = preferencia,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BuscarCaronaTela(
          idUsuario: id,
          cidadeInicial: cidadeA.cidade,
          localizacaoReferencia: comReferencia ? referenciaA : null,
          destinoInicial: comDestino ? campi[1].localizacao : null,
          campusService: catalogo,
          enderecoService: enderecos,
          catalogoCidadesService: const CidadesTeste(),
          cidadePesquisaService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('busca ativa lista e reaproveita GPS da Home sem nova consulta', (
    tester,
  ) async {
    await executar(() async {
      await montar(tester);
      expect(catalogo.consultasGps, 0);
      expect(catalogo.buscas.single.mesmaCidade(cidadeA), isTrue);
      expect(resultados(tester), [1, 2]);
      final campo = tester.widget<CampoDestinoCampus>(
        find.byType(CampoDestinoCampus),
      );
      expect(campo.selecionarCidadeNaLista, isTrue);
      expect(campo.idUsuario, 7);
      await abrirCidades(tester);
      expect(
        find.byKey(ValueKey('cidade-${cidadeA.cidade}-SP')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cidade-Birigui-SP')), findsOneWidget);
      expect(find.text('Usar localização atual'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('pesquisa-cidade')),
        'ARACATUBA',
      );
      await tester.pump();
      expect(
        find.byKey(ValueKey('cidade-${cidadeA.cidade}-SP')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cidade-Birigui-SP')), findsNothing);
      expect(consultasCaronas, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'restaura cidade salva e ordena resultados antes de focar campo',
    (tester) async {
      await preferencia.salvar(7, birigui);
      await executar(() async {
        await montar(tester);
        expect(catalogo.consultasGps, 0);
        expect(catalogo.buscas.single.mesmaCidade(birigui), isTrue);
        expect(resultados(tester), [2, 1]);
        expect(consultasCaronas, 1);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets('mudar cidade limpa coordenadas antigas sem apagar Ir para', (
    tester,
  ) async {
    final destino = campi[1].localizacao!;
    await const DestinoPreferidoService().salvar(7, destino);
    await executar(() async {
      await montar(tester, comDestino: true);
      expect(resultados(tester), [1]);
      await escolherCidade(tester, birigui);
      expect(filtros(tester).destinoController.text, isEmpty);
      expect(resultados(tester), [2, 1]);
      expect((await preferencia.carregar(7))!.mesmaCidade(birigui), isTrue);
      expect(
        (await const DestinoPreferidoService().carregar(7))!.toJson(),
        destino.toJson(),
      );
      await tester.enterText(campoDestino, 'Faculdade');
      await tester.pumpAndSettle();
      await tocar(tester, find.text(campusBirigui.titulo));
      expect(resultados(tester), [2]);
      expect(consultasCaronas, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'troca de cidade conserva data e horario e limpar conserva cidade',
    (tester) async {
      await executar(() async {
        await montar(tester);
        filtros(tester).onSelecionarData();
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        filtros(tester).onSelecionarHorario();
        await tester.pumpAndSettle();
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .onDateTimeChanged(DateTime(2026, 1, 1, 18));
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        final data = filtros(tester).dataController.text;
        expect(data, isNotEmpty);
        expect(filtros(tester).horarioController.text, '18:00');
        await escolherCidade(tester, birigui);
        expect(filtros(tester).dataController.text, data);
        expect(filtros(tester).horarioController.text, '18:00');
        filtros(tester).onLimparFiltros();
        await tester.pumpAndSettle();
        expect(filtros(tester).dataController.text, isEmpty);
        expect(filtros(tester).horarioController.text, isEmpty);
        expect((await preferencia.carregar(7))!.mesmaCidade(birigui), isTrue);
        expect(resultados(tester), [2, 1]);
        expect(consultasCaronas, 1);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets('preferencia escolhida na busca aparece na escolha da Home', (
    tester,
  ) async {
    await executar(() async {
      await montar(tester);
      await escolherCidade(tester, birigui);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: SelecionarDestinoTela(
            idUsuario: 7,
            localizacaoReferencia: referenciaA,
            campusService: catalogo,
            enderecoService: enderecos,
            catalogoCidadesService: const CidadesTeste(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Birigui, SP'), findsWidgets);
      expect(find.text(campusBirigui.titulo), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final gpsDisponivel in [true, false]) {
    testWidgets(
      'volta ao GPS preserva escolha se indisponivel: $gpsDisponivel',
      (tester) async {
        await preferencia.salvar(7, birigui);
        catalogo.cidadeDetectada = gpsDisponivel ? cidadeA : null;
        await executar(() async {
          await montar(tester);
          await abrirCidades(tester);
          await tocar(tester, find.text('Usar localização atual'));
          expect(catalogo.consultasGps, 1);
          expect(resultados(tester), gpsDisponivel ? [1, 2] : [2, 1]);
          expect(
            (await preferencia.carregar(7))?.cidade,
            gpsDisponivel ? null : birigui.cidade,
          );
          if (!gpsDisponivel) {
            expect(
              find.text('Não foi possível identificar sua cidade.'),
              findsOneWidget,
            );
          }
          await tester.pumpWidget(const SizedBox());
        });
      },
    );
  }

  testWidgets('falha ao salvar conserva destino, cidade e resultados', (
    tester,
  ) async {
    final service = PreferenciaTeste()..falharGravacao = true;
    await executar(() async {
      await montar(tester, comDestino: true, service: service);
      final destino = filtros(tester).destinoController.text;
      await escolherCidade(tester, birigui);
      expect(filtros(tester).destinoController.text, destino);
      expect(resultados(tester), [1]);
      expect(await preferencia.carregar(7), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('outra conta nao herda cidade salva', (tester) async {
    await preferencia.salvar(99, birigui);
    await executar(() async {
      await montar(tester);
      expect(catalogo.buscas.single.mesmaCidade(cidadeA), isTrue);
      expect(resultados(tester), [1, 2]);
      expect((await preferencia.carregar(99))!.mesmaCidade(birigui), isTrue);
      expect(await preferencia.carregar(7), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets(
    'reabrir busca restaura cidade escolhida sem alterar destino salvo',
    (tester) async {
      await executar(() async {
        await montar(tester);
        await escolherCidade(tester, birigui);
        await tester.pumpWidget(const SizedBox());
        await montar(tester);
        expect(catalogo.buscas.last.mesmaCidade(birigui), isTrue);
        expect(resultados(tester), [2, 1]);
        expect(catalogo.consultasGps, 0);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  testWidgets('sem referencia so consulta GPS quando abre campo', (
    tester,
  ) async {
    await executar(() async {
      await montar(tester, comReferencia: false);
      expect(catalogo.consultasGps, 0);
      expect(catalogo.buscas, isEmpty);
      await tocar(tester, campoDestino);
      expect(catalogo.consultasGps, 1);
      expect(catalogo.buscas.single.mesmaCidade(cidadeA), isTrue);
      expect(resultados(tester), [1, 2]);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('campi atrasados nao restauram cidade nem ordenacao anterior', (
    tester,
  ) async {
    final antigos = Completer<List<CampusDestino>>();
    catalogo.resposta = (cidade) => cidade.mesmaCidade(cidadeA)
        ? antigos.future
        : Future.value([campusBirigui]);
    await executar(() async {
      await montar(tester);
      await escolherCidade(tester, birigui);
      antigos.complete(campi);
      await tester.pumpAndSettle();
      expect(resultados(tester), [2, 1]);
      expect(find.text(campi[1].titulo), findsNothing);
      expect(find.text(campusBirigui.titulo), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  for (final leituraDaPreferencia in [true, false]) {
    testWidgets(
      'resposta antiga nao desfaz cidade nova: $leituraDaPreferencia',
      (tester) async {
        final pendente = Completer<CidadeCampus?>();
        final service = PreferenciaTeste();
        if (leituraDaPreferencia) {
          service.leitura = pendente.future;
        } else {
          catalogo.deteccao = pendente.future;
        }
        await executar(() async {
          await montar(tester, service: service, comReferencia: false);
          await escolherCidade(tester, birigui);
          pendente.complete(cidadeA);
          await tester.pumpAndSettle();
          expect(catalogo.buscas.single.mesmaCidade(birigui), isTrue);
          expect(resultados(tester), [2, 1]);
          await tester.pumpWidget(const SizedBox());
        });
      },
    );
  }

  testWidgets('fechar durante restauracao nao atualiza tela descartada', (
    tester,
  ) async {
    final pendente = Completer<CidadeCampus?>();
    final service = PreferenciaTeste()..leitura = pendente.future;
    await executar(() async {
      await montar(tester, service: service);
      await tester.pumpWidget(const SizedBox());
      pendente.complete(birigui);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(await preferencia.carregar(7), isNull);
    });
  });
}
