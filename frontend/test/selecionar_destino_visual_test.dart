import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';

import 'campo_destino_campus_test.dart'
    show CatalogoTeste, EnderecosTeste, campi, cidadeA, referenciaA;

Future<void> abrirDestino(
  WidgetTester tester, {
  required CatalogoTeste catalogo,
  required EnderecosTeste enderecos,
  LocalizacaoSelecionada? destinoInicial,
  double escala = 1,
  double alturaTeclado = 0,
  ValueChanged<LocalizacaoSelecionada?>? aoVoltar,
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
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final local = await Navigator.of(context)
                  .push<LocalizacaoSelecionada>(
                    MaterialPageRoute(
                      builder: (_) => SelecionarDestinoTela(
                        destinoInicial: destinoInicial,
                        campusService: catalogo,
                        enderecoService: enderecos,
                      ),
                    ),
                  );
              aoVoltar?.call(local);
            },
            child: const Text('Abrir destino'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir destino'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    final fontes = FontLoader('Inter');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fontes.addFont(rootBundle.load('assets/fontes/Inter_18pt-$peso.ttf'));
    }
    await fontes.load();
  });

  late CatalogoTeste catalogo;
  late EnderecosTeste enderecos;
  const rolagem = ValueKey('rolagem-escolher-destino');
  setUp(() {
    catalogo = CatalogoTeste();
    enderecos = EnderecosTeste();
    final anterior = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = anterior);
  });

  testWidgets('mostra cidade dinamica, campi distintos e apenas uma rolagem', (
    tester,
  ) async {
    await abrirDestino(tester, catalogo: catalogo, enderecos: enderecos);
    await tester.pumpAndSettle();
    expect(find.text('Escolher destino'), findsOneWidget);
    expect(find.text('Araçatuba, SP'), findsWidgets);
    expect(find.text('Alterar'), findsOneWidget);
    expect(find.text('Faculdade ou endereço'), findsOneWidget);
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(find.text(campi[2].titulo), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsNWidgets(3));
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('campus-destino-1')))
          .titleTextStyle!
          .fontFamily,
      'Inter',
    );
    expect(find.byType(ListView), findsNothing);
    expect(find.byKey(rolagem), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
    expect(enderecos.buscas, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserva texto salvo sem esconder a lista inicial', (
    tester,
  ) async {
    final salvo = campi.first.localizacao!;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      destinoInicial: salvo,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      salvo.descricaoCompleta,
    );
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(enderecos.buscas, isEmpty);
  });

  testWidgets('filtra campi desde uma letra e so busca enderecos com tres', (
    tester,
  ) async {
    await abrirDestino(tester, catalogo: catalogo, enderecos: enderecos);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'od');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(find.text(campi[2].titulo), findsNothing);
    expect(enderecos.buscas, isEmpty);
    await tester.enterText(find.byType(TextField), 'unesp VETERINARIA');
    await tester.pump(const Duration(milliseconds: 499));
    expect(enderecos.buscas, isEmpty);
    expect(find.text(campi[2].titulo), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(enderecos.buscas, ['unesp VETERINARIA']);
    await tester.tap(find.byTooltip('Limpar destino'));
    await tester.pumpAndSettle();
    expect(find.text(campi.first.titulo), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('selecionar retorna exatamente o campus escolhido para a Home', (
    tester,
  ) async {
    LocalizacaoSelecionada? retorno;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      aoVoltar: (local) => retorno = local,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(campi[2].titulo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(campi[2].titulo));
    await tester.pumpAndSettle();
    expect(retorno!.toJson(), campi[2].localizacao!.toJson());
    expect(retorno!.ponto, isNot(campi[1].ponto));
    expect(find.byType(SelecionarDestinoTela), findsNothing);
    expect(enderecos.buscas, isEmpty);
  });

  testWidgets('voltar cancela a selecao sem retornar nem modificar o destino', (
    tester,
  ) async {
    var retornou = false;
    LocalizacaoSelecionada? retorno;
    final salvo = campi.first.localizacao!;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      destinoInicial: salvo,
      aoVoltar: (local) {
        retornou = true;
        retorno = local;
      },
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'od');
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(retornou, isTrue);
    expect(retorno, isNull);
    expect(salvo.toJson(), campi.first.localizacao!.toJson());
  });

  testWidgets('linha adaptada para fonte ampliada continua selecionavel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LocalizacaoSelecionada? retorno;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      escala: 2,
      aoVoltar: (local) => retorno = local,
    );
    await tester.pumpAndSettle();
    final campus = find.byKey(const ValueKey('campus-destino-2'));
    await tester.scrollUntilVisible(
      campus,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(rolagem),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget(campus), isA<InkWell>());
    await tester.ensureVisible(find.text(campi[1].titulo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(campi[1].titulo));
    await tester.pumpAndSettle();
    expect(retorno!.toJson(), campi[1].localizacao!.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem GPS permite definir cidade e UF sem fixar Aracatuba', (
    tester,
  ) async {
    catalogo.cidadeDetectada = null;
    catalogo.resposta = (_) async => [];
    await abrirDestino(tester, catalogo: catalogo, enderecos: enderecos);
    await tester.pumpAndSettle();
    expect(find.text('Selecionar cidade'), findsOneWidget);
    expect(find.textContaining('Localização indisponível'), findsOneWidget);
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Rio Branco');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC · Acre').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Rio Branco, AC'), findsOneWidget);
    expect(catalogo.buscas.single.uf, 'AC');
    expect(
      find.text('Nenhuma faculdade cadastrada nesta cidade.'),
      findsOneWidget,
    );
  });

  testWidgets('erro no catalogo mantem pesquisa e permite tentar novamente', (
    tester,
  ) async {
    catalogo.resposta = (_) async => throw StateError('offline');
    await abrirDestino(tester, catalogo: catalogo, enderecos: enderecos);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar as faculdades.'),
      findsOneWidget,
    );
    expect(
      find.text('Nenhuma faculdade cadastrada nesta cidade.'),
      findsNothing,
    );
    catalogo.resposta = (_) async => campi;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text(campi.first.titulo), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  for (final tipo in TipoFalhaEndereco.values) {
    testWidgets('erro $tipo nos enderecos nao impede selecionar campus', (
      tester,
    ) async {
      enderecos.resposta = (_) async => throw FalhaBuscaEndereco(tipo);
      LocalizacaoSelecionada? retorno;
      await abrirDestino(
        tester,
        catalogo: catalogo,
        enderecos: enderecos,
        aoVoltar: (local) => retorno = local,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'odontologia');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text(FalhaBuscaEndereco(tipo).mensagem), findsOneWidget);
      expect(find.textContaining('Nenhum endereço encontrado'), findsNothing);
      await tester.tap(find.text(campi[1].titulo));
      await tester.pumpAndSettle();
      expect(retorno!.ponto, campi[1].ponto);
    });
  }

  testWidgets('campus sem ponto continua exigindo confirmacao do endereco', (
    tester,
  ) async {
    const semPonto = CampusDestino(
      idCampus: 4,
      idInstituicao: 4,
      nome: 'Faculdade de Tecnologia',
      sigla: 'FATEC',
      campus: 'Araçatuba',
      cidade: cidadeA,
    );
    catalogo.resposta = (_) async => [semPonto];
    const local = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Fatec',
      endereco: 'Rua da faculdade, 10',
      cidade: 'Araçatuba',
      estado: 'SP',
    );
    enderecos.resposta = (_) async => [local];
    LocalizacaoSelecionada? retorno;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      aoVoltar: (valor) => retorno = valor,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsNWidgets(2));
    await tester.tap(find.text(semPonto.titulo));
    await tester.pumpAndSettle();
    expect(retorno, isNull);
    expect(find.textContaining('Confirme o endereço'), findsOneWidget);
    await tester.tap(find.text('Fatec'));
    await tester.pumpAndSettle();
    expect(retorno!.toJson(), local.toJson());
  });

  testWidgets('resposta antiga e descarte da tela nao geram estado invalido', (
    tester,
  ) async {
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    enderecos.resposta = (_) => pendente.future;
    await abrirDestino(tester, catalogo: catalogo, enderecos: enderecos);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rua antiga');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Limpar destino'));
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    pendente.complete([referenciaA]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SelecionarDestinoTela), findsNothing);
  });

  testWidgets('lista grande cria linhas sob demanda e chega ao ultimo campus', (
    tester,
  ) async {
    final muitos = List.generate(
      150,
      (indice) => CampusDestino(
        idCampus: indice + 1,
        idInstituicao: indice + 1,
        nome: 'Universidade $indice',
        campus: 'Campus $indice',
        cidade: cidadeA,
        ponto: const LatLng(-21.2, -50.4),
      ),
    );
    catalogo.resposta = (_) async => muitos;
    LocalizacaoSelecionada? retorno;
    await abrirDestino(
      tester,
      catalogo: catalogo,
      enderecos: enderecos,
      aoVoltar: (valor) => retorno = valor,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThan(20));
    final ultimo = find.byKey(const ValueKey('campus-destino-150'));
    await tester.scrollUntilVisible(
      ultimo,
      500,
      scrollable: find
          .descendant(
            of: find.byKey(rolagem),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();
    await tester.tap(ultimo);
    await tester.pumpAndSettle();
    expect(retorno!.nome, muitos.last.titulo);
  });

  for (final tamanho in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(800, 600),
  ]) {
    for (final escala in [1.0, 2.0]) {
      for (final teclado in [0.0, 250.0]) {
        testWidgets(
          'layout $tamanho fonte $escala teclado $teclado sem overflow',
          (tester) async {
            tester.view.physicalSize = tamanho;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.view.viewInsets = FakeViewPadding(bottom: teclado);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPadding);
            addTearDown(tester.view.resetViewInsets);
            catalogo.cidadeDetectada = const CidadeCampus(
              'São José do Vale do Rio Preto',
              'RJ',
            );
            catalogo.resposta = (_) async => [
              const CampusDestino(
                idCampus: 5,
                idInstituicao: 5,
                nome: 'Universidade Federal com Nome Extenso',
                campus: 'Campus de Engenharia e Tecnologia da Informação',
                cidade: CidadeCampus('São José do Vale do Rio Preto', 'RJ'),
                ponto: LatLng(-22.15, -42.92),
              ),
            ];
            await abrirDestino(
              tester,
              catalogo: catalogo,
              enderecos: enderecos,
              escala: escala,
              alturaTeclado: teclado,
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(rolagem)).bottom,
              lessThanOrEqualTo(tamanho.height - teclado),
            );
            final seta = tester.getRect(find.byTooltip('Voltar'));
            expect(seta.top, greaterThanOrEqualTo(24));
            expect(seta.bottom, lessThanOrEqualTo(80));
            await tester.ensureVisible(find.byType(TextField));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'en');
            await tester.pumpAndSettle();
            final campus = find.byKey(const ValueKey('campus-destino-5'));
            await tester.scrollUntilVisible(
              campus,
              150,
              scrollable: find
                  .descendant(
                    of: find.byKey(rolagem),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            expect(find.byType(CampoDestinoCampus), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(tester.getRect(find.byTooltip('Voltar')), seta);
          },
        );
      }
    }
  }
}
