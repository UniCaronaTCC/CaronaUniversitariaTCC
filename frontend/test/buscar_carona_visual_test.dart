import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/utils/data_hora_utils.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';
import 'package:uni_carona/widgets/campo_texto_carona.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/filtros_busca_carona.dart';

import 'buscar_carona_erros_test.dart' as base;
import 'campo_destino_campus_test.dart'
    show CatalogoTeste, EnderecosTeste, campi;

Map<String, dynamic> ofertaVisual(
  int id, {
  String destino = 'UniSALESIANO · Araçatuba',
  String horario = '18:10',
  int dias = 0,
}) => {
  ...base.carona(id, destino: destino),
  'dataInicio': DataHoraUtils.formatarDataBackend(
    DateTime.now().add(Duration(days: dias)),
  ),
  'horario': horario,
  'pontosEmbarque': [
    {
      'idPontoEmbarque': 1,
      'nome': 'Praça Rui Barbosa',
      'endereco': 'Rua central, 10',
      'latitude': -21.2,
      'longitude': -50.4,
      'ordem': 1,
    },
  ],
  'usuario': {
    'idUsuario': 20 + id,
    'nome': id == 1 ? 'Henrique' : 'Pedro',
    'veiculo': {'modelo': 'Onix', 'cor': 'Branco'},
  },
};

Future<void> montarBuscaVisual(
  WidgetTester tester, {
  LocalizacaoSelecionada? destino,
  double escala = 1,
  double alturaTeclado = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
          viewInsets: EdgeInsets.only(bottom: alturaTeclado),
        ),
        child: child!,
      ),
      home: BuscarCaronaTela(destinoInicial: destino),
    ),
  );
  await tester.pumpAndSettle();
}

Finder campoFiltro(String nome) => find.descendant(
  of: find.byKey(ValueKey('filtro-$nome')),
  matching: find.byType(TextField),
);

List<int> idsVisuais(WidgetTester tester) => tester
    .widgetList<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
    .map((card) => card.carona.id)
    .toList();

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fontes = FontLoader('Inter');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fontes.addFont(rootBundle.load('assets/fontes/Inter_18pt-$peso.ttf'));
    }
    await fontes.load();
  });
  setUp(() {
    AuthService.tokenUsuarioLogado = 'token-teste';
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });
  tearDown(() => AuthService.tokenUsuarioLogado = null);

  testWidgets('busca reaproveita card da Home sem duplicar titulo', (
    tester,
  ) async {
    await base.executar(() async {
      await montarBuscaVisual(tester);
      expect(find.text('Buscar carona'), findsOneWidget);
      expect(find.text('Filtros'), findsOneWidget);
      expect(find.text('Encontre uma viagem para o seu destino'), findsNothing);
      final card = tester.widget<CardCaronaDisponivel>(
        find.byType(CardCaronaDisponivel),
      );
      expect(card.visualHome, isTrue);
      expect(find.text('Henrique'), findsOneWidget);
      expect(find.text('H'), findsOneWidget);
      expect(find.text('Onix • Branco'), findsOneWidget);
      expect(find.text('por pessoa'), findsOneWidget);
      expect(find.text('Horário do primeiro encontro'), findsOneWidget);
      expect(find.byKey(const ValueKey('linha-trajeto-home')), findsOneWidget);
      expect(find.text('Solicitar carona'), findsNothing);
      expect(find.byKey(const ValueKey('limpar-filtros-busca')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => base.lista([ofertaVisual(1)])));
  });

  testWidgets('limpar pela interface restaura resultados sem nova consulta', (
    tester,
  ) async {
    var consultas = 0;
    await base.executar(
      () async {
        await montarBuscaVisual(tester);
        final destino = find.descendant(
          of: find.byType(CampoDestinoCampus),
          matching: find.byType(TextField),
        );
        await tester.enterText(destino, 'Campus B');
        await tester.pumpAndSettle();
        expect(idsVisuais(tester), [2]);
        await tocar(tester, find.byKey(const ValueKey('limpar-filtros-busca')));
        expect(idsVisuais(tester), [1, 2]);
        expect(consultas, 1);
        expect(tester.widget<TextField>(destino).controller!.text, isEmpty);
        expect(
          find.byKey(const ValueKey('limpar-filtros-busca')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((_) async {
        consultas++;
        return base.lista([
          ofertaVisual(1),
          ofertaVisual(2, destino: 'Campus B'),
        ]);
      }),
    );
  });

  testWidgets('destino selecionado continua filtrando por coordenadas', (
    tester,
  ) async {
    const destino = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Outro nome para o mesmo campus',
      endereco: 'Rua do campus, 10',
    );
    await base.executar(
      () async {
        await montarBuscaVisual(tester, destino: destino);
        expect(idsVisuais(tester), [1]);
        final filtros = tester.widget<FiltrosBuscaCarona>(
          find.byType(FiltrosBuscaCarona),
        );
        expect(filtros.destinoController.text, destino.descricaoCompleta);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (_) async => base.lista([
          ofertaVisual(1),
          {...ofertaVisual(2), 'destinoLatitude': -23.5},
        ]),
      ),
    );
  });

  testWidgets('data abre calendario, filtra e limpar remove data e horario', (
    tester,
  ) async {
    var consultas = 0;
    await base.executar(
      () async {
        await montarBuscaVisual(tester);
        await tocar(tester, campoFiltro('data'));
        expect(find.byType(DatePickerDialog), findsOneWidget);
        await tester.tap(find.text('${DateTime.now().day}').last);
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        expect(idsVisuais(tester), [1]);
        expect(
          tester.widget<TextField>(campoFiltro('data')).controller!.text,
          DataHoraUtils.formatarDataExibicao(DateTime.now()),
        );
        await tocar(tester, campoFiltro('horario'));
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .onDateTimeChanged(DateTime(2026, 1, 1, 18));
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(campoFiltro('horario')).controller!.text,
          '18:00',
        );
        await tocar(tester, find.byKey(const ValueKey('limpar-filtros-busca')));
        expect(idsVisuais(tester), [1, 2]);
        expect(
          tester.widget<TextField>(campoFiltro('data')).controller!.text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(campoFiltro('horario')).controller!.text,
          isEmpty,
        );
        expect(consultas, 1);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((_) async {
        consultas++;
        return base.lista([ofertaVisual(1), ofertaVisual(2, dias: 1)]);
      }),
    );
  });

  testWidgets('horario preferido ordena sem excluir outras caronas', (
    tester,
  ) async {
    await base.executar(
      () async {
        await montarBuscaVisual(tester);
        await tocar(tester, campoFiltro('horario'));
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .onDateTimeChanged(DateTime(2026, 1, 1, 19));
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        expect(idsVisuais(tester), [2, 1]);
        expect(
          tester.widget<TextField>(campoFiltro('horario')).controller!.text,
          '19:00',
        );
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (_) async => base.lista([
          ofertaVisual(1, horario: '18:00'),
          ofertaVisual(2, horario: '19:10'),
        ]),
      ),
    );
  });

  testWidgets('cancelar calendario e horario preserva campos e resultados', (
    tester,
  ) async {
    await base.executar(() async {
      await montarBuscaVisual(tester);
      for (final campo in ['data', 'horario']) {
        await tocar(tester, campoFiltro(campo));
        await tester.tap(find.text('CANCELAR'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(campoFiltro(campo)).controller!.text,
          isEmpty,
        );
        expect(idsVisuais(tester), [1]);
      }
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => base.lista([ofertaVisual(1)])));
  });

  testWidgets('tocar no card abre os detalhes da mesma carona', (tester) async {
    await base.executar(() async {
      await montarBuscaVisual(tester);
      await tocar(tester, find.text('Henrique'));
      expect(find.byType(DetalhesCaronaTela), findsOneWidget);
      expect(
        tester
            .widget<DetalhesCaronaTela>(find.byType(DetalhesCaronaTela))
            .carona
            .id,
        1,
      );
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(BuscarCaronaTela), findsOneWidget);
      expect(idsVisuais(tester), [1]);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((_) async => base.lista([ofertaVisual(1)])));
  });

  testWidgets(
    'novo campo de destino e compacto e preserva sugestoes e selecao',
    (tester) async {
      final controller = TextEditingController();
      final catalogo = CatalogoTeste();
      final enderecos = EnderecosTeste();
      LocalizacaoSelecionada? escolhido;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CampoDestinoCampus(
                controller: controller,
                campusService: catalogo,
                enderecoService: enderecos,
                visualAtualizado: true,
                onSelecionado: (local) => escolhido = local,
              ),
            ),
          ),
        ),
      );
      expect(catalogo.buscas, isEmpty);
      expect(find.byType(CustomScrollView), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
      await tocar(tester, find.byType(TextField));
      expect(catalogo.buscas, hasLength(1));
      await tester.enterText(find.byType(TextField), 'od');
      await tester.pumpAndSettle();
      expect(find.text(campi[1].titulo), findsOneWidget);
      expect(find.text(campi[2].titulo), findsNothing);
      expect(enderecos.buscas, isEmpty);
      await tocar(tester, find.text(campi[1].titulo));
      expect(escolhido!.toJson(), campi[1].localizacao!.toJson());
      expect(controller.text, escolhido!.descricaoCompleta);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final atualizado in [false, true]) {
    testWidgets('campo de texto opcional preserva estilo padrao: $atualizado', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CampoTextoCarona(
              label: 'Data',
              icone: Icons.calendar_today_outlined,
              controller: controller,
              visualAtualizado: atualizado,
              somenteLeitura: true,
            ),
          ),
        ),
      );
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.readOnly, isTrue);
      expect(campo.decoration!.labelText, atualizado ? null : 'Data');
      expect(
        campo.decoration!.fillColor,
        atualizado ? const Color(0xFFF6F6F9) : Colors.white,
      );
      expect(
        (campo.decoration!.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(atualizado ? 8 : 16),
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  for (final teclado in [0.0, 250.0]) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('busca completa estreita fonte $escala teclado $teclado', (
        tester,
      ) async {
        await base.executar(() async {
          await tester.binding.setSurfaceSize(const Size(320, 640));
          await montarBuscaVisual(
            tester,
            escala: escala,
            alturaTeclado: teclado,
          );
          final seta = tester.getRect(find.byTooltip('Voltar'));
          await tester.scrollUntilVisible(
            find.text('Henrique'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Henrique'), findsOneWidget);
          expect(tester.getRect(find.byTooltip('Voltar')), seta);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }, () => MockClient((_) async => base.lista([ofertaVisual(1)])));
      });
    }
  }

  for (final tamanho in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final escala in [1.0, 1.5, 2.0]) {
      for (final teclado in [0.0, 250.0]) {
        testWidgets('filtros em $tamanho fonte $escala teclado $teclado', (
          tester,
        ) async {
          tester.view.physicalSize = tamanho;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final destino = TextEditingController(
            text: 'Universidade com nome extenso · Campus Araçatuba',
          );
          final data = TextEditingController(text: '29/10');
          final horario = TextEditingController(text: '18:00');
          var datas = 0;
          var horarios = 0;
          var limpezas = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(escala),
                  viewInsets: EdgeInsets.only(bottom: teclado),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FiltrosBuscaCarona(
                    destinoController: destino,
                    dataController: data,
                    horarioController: horario,
                    filtrosAtivos: true,
                    onDestinoChanged: (_) {},
                    onDestinoSelecionado: (_) {},
                    onSelecionarData: () => datas++,
                    onSelecionarHorario: () => horarios++,
                    onLimparFiltros: () => limpezas++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final posData = tester.getRect(
            find.byKey(const ValueKey('filtro-data')),
          );
          final posHorario = tester.getRect(
            find.byKey(const ValueKey('filtro-horario')),
          );
          if (tamanho.width - 48 < 320 || escala > 1.25) {
            expect(posHorario.top, greaterThanOrEqualTo(posData.bottom + 16));
          } else {
            expect(posData.top, posHorario.top);
            expect(posHorario.left, greaterThan(posData.right));
          }
          for (final nome in ['data', 'horario']) {
            await tocar(tester, campoFiltro(nome));
            expect(
              tester.widget<TextField>(campoFiltro(nome)).readOnly,
              isTrue,
            );
            final render = tester.renderObject<RenderBox>(campoFiltro(nome));
            expect(render.size.height, greaterThanOrEqualTo(48));
          }
          await tocar(
            tester,
            find.byKey(const ValueKey('limpar-filtros-busca')),
          );
          expect((datas, horarios, limpezas), (1, 1, 1));
          expect(data.text, '29/10');
          expect(horario.text, '18:00');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          destino.dispose();
          data.dispose();
          horario.dispose();
        });
      }
    }
  }
}
