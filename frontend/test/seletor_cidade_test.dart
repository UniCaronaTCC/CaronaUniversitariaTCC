import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/catalogo_cidades_service.dart';
import 'package:uni_carona/widgets/seletor_cidade.dart';

class CatalogoSeletorTeste extends CatalogoCidadesService {
  int chamadas = 0;
  bool falha = false;
  Future<List<CidadeCampus>>? pendente;
  @override
  Future<List<CidadeCampus>> listar() async {
    chamadas++;
    if (falha) throw StateError('catalogo');
    return pendente ??
        Future.value(const [
          CidadeCampus('Araçatuba', 'SP'),
          CidadeCampus('Bom Jesus', 'PI'),
          CidadeCampus('Bom Jesus', 'RS'),
          CidadeCampus('Manaus', 'AM'),
        ]);
  }
}

Future<void> abrir(
  WidgetTester tester,
  CatalogoCidadesService catalogo, {
  double escala = 1,
  double teclado = 0,
  CidadeCampus? cidade,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(escala),
          viewInsets: EdgeInsets.only(bottom: teclado),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<SelecaoCidade>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  SeletorCidade(cidadeAtual: cidade, catalogoService: catalogo),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets(
    'catalogo nacional real filtra offline e cria linhas sob demanda',
    (tester) async {
      const catalogo = CatalogoCidadesService();
      await tester.runAsync(catalogo.listar);
      await abrir(tester, catalogo);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(100));
      await tester.enterText(
        find.byKey(const ValueKey('pesquisa-cidade')),
        'aracatuba',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
      expect(find.text('Nenhuma cidade encontrada.'), findsNothing);
    },
  );
  testWidgets('UF filtra e todos os estados permite homonimos separados', (
    tester,
  ) async {
    await abrir(
      tester,
      CatalogoSeletorTeste(),
      cidade: const CidadeCampus('Araçatuba', 'SP'),
    );
    expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
    expect(find.byKey(const ValueKey('cidade-Bom Jesus-PI')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('estado-cidades')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Todos os estados'),
      -250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Todos os estados').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-cidade')),
      'bom jesus',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('cidade-Bom Jesus-PI')), findsOneWidget);
    expect(find.byKey(const ValueKey('cidade-Bom Jesus-RS')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-cidade')),
      'nao existe',
    );
    await tester.pump();
    expect(find.text('Nenhuma cidade encontrada.'), findsOneWidget);
    await tester.tap(find.byTooltip('Limpar pesquisa de cidade'));
    await tester.pump();
    expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
  });

  testWidgets('erro permite repetir sem requisicoes por letra digitada', (
    tester,
  ) async {
    final catalogo = CatalogoSeletorTeste()..falha = true;
    await abrir(tester, catalogo);
    expect(find.text('Não foi possível carregar as cidades.'), findsOneWidget);
    catalogo.falha = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-cidade')),
      'arac',
    );
    await tester.pump();
    expect(catalogo.chamadas, 2);
    expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
  });

  testWidgets('fechar durante carregamento nao causa setState apos dispose', (
    tester,
  ) async {
    final pendente = Completer<List<CidadeCampus>>();
    await abrir(tester, CatalogoSeletorTeste()..pendente = pendente.future);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pendente.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets('lista cabe em tela estreita com teclado e fonte $escala', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(tester, CatalogoSeletorTeste(), escala: escala, teclado: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('pesquisa-cidade')));
      await tester.enterText(
        find.byKey(const ValueKey('pesquisa-cidade')),
        'manaus',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('cidade-Manaus-AM')),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
