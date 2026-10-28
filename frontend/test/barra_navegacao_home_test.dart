import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/barra_navegacao_home.dart';

void main() {
  testWidgets('exibe Chat no lugar de Buscar', (tester) async {
    int? itemSelecionado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            totalMensagensNaoLidas: 0,
            totalSolicitacoesPendentes: 0,
            onTap: (index) {
              itemSelecionado = index;
            },
          ),
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chat_bubble), findsOneWidget);
    expect(find.text('Buscar'), findsNothing);
    expect(find.text('Caronas'), findsOneWidget);
    expect(find.text('Publicar'), findsNothing);

    await tester.tap(find.text('Caronas'));

    expect(itemSelecionado, 2);
  });

  testWidgets('permite destacar a área de Caronas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            currentIndex: 2,
            totalMensagensNaoLidas: 0,
            totalSolicitacoesPendentes: 0,
          ),
        ),
      ),
    );

    final barra = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(barra.currentIndex, 2);
  });

  testWidgets('mostra o total de mensagens não lidas no Chat', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            totalMensagensNaoLidas: 3,
            totalSolicitacoesPendentes: 0,
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('oculta o contador quando não existem mensagens não lidas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            totalMensagensNaoLidas: 0,
            totalSolicitacoesPendentes: 0,
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('mostra solicitações pendentes no item Caronas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            totalMensagensNaoLidas: 0,
            totalSolicitacoesPendentes: 4,
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget);
  });

  for (final indice in [0, 1, 2, 3]) {
    testWidgets('icones e navegacao preservados na aba $indice', (
      tester,
    ) async {
      final toques = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BarraNavegacaoHome(
              currentIndex: indice,
              totalMensagensNaoLidas: 3,
              totalSolicitacoesPendentes: 4,
              onTap: toques.add,
            ),
          ),
        ),
      );
      expect(
        find.byIcon(
          indice == 0 ? CupertinoIcons.house_fill : CupertinoIcons.house,
        ),
        findsOneWidget,
      );
      expect(
        find.byIcon(
          indice == 1
              ? CupertinoIcons.chat_bubble_fill
              : CupertinoIcons.chat_bubble,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.directions_car_filled_outlined), findsOneWidget);
      expect(
        find.byIcon(
          indice == 3 ? CupertinoIcons.person_fill : CupertinoIcons.person,
        ),
        findsOneWidget,
      );
      expect(find.byType(Badge), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      for (final rotulo in ['Início', 'Chat', 'Caronas', 'Perfil']) {
        await tester.tap(find.text(rotulo));
      }
      expect(toques, [0, 1, 2, 3]);
      final barra = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(barra.currentIndex, indice);
      expect(barra.backgroundColor, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('barra cabe em tela estreita com fonte ampliada e contadores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: const Scaffold(
          bottomNavigationBar: BarraNavegacaoHome(
            totalMensagensNaoLidas: 1000,
            totalSolicitacoesPendentes: 1000,
          ),
        ),
      ),
    );
    expect(find.byType(Badge), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
