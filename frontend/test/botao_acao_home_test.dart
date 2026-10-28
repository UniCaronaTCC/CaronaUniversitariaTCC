import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/widgets/botao_acao_home.dart';

void main() {
  for (final estilo in EstiloBotaoAcaoHome.values) {
    testWidgets('carregamento impede toque e preserva tamanho: $estilo', (
      tester,
    ) async {
      var toques = 0;
      Widget montar(bool carregando) => MaterialApp(
        home: Scaffold(
          body: BotaoAcaoHome(
            texto: 'Buscar carona',
            icone: Icons.search,
            estilo: estilo,
            carregando: carregando,
            onPressed: () => toques++,
          ),
        ),
      );
      await tester.pumpWidget(montar(false));
      final tamanho = tester.getSize(find.byType(BotaoAcaoHome));
      await tester.pumpWidget(montar(true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(BotaoAcaoHome)), tamanho);
      final controle = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      );
      expect(controle.onPressed, isNull);
      await tester.tap(find.text('Buscar carona'));
      expect(toques, 0);
      await tester.pumpWidget(montar(false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar carona'));
      expect(toques, 1);
    });
  }
  testWidgets('estilo padrao preserva o botao usado na publicacao', (
    tester,
  ) async {
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotaoAcaoHome(
            texto: 'OFERTAR CARONA',
            icone: Icons.groups_outlined,
            onPressed: () => toques++,
          ),
        ),
      ),
    );
    final controle = find.byWidgetPredicate(
      (widget) => widget is ElevatedButton,
    );
    expect(tester.getSize(find.byType(BotaoAcaoHome)).height, 82);
    expect(tester.widget<Icon>(find.byIcon(Icons.groups_outlined)).size, 32);
    expect(
      tester.widget<Text>(find.text('OFERTAR CARONA')).style?.fontSize,
      24,
    );
    expect(
      tester.widget<ElevatedButton>(controle).style?.elevation?.resolve({}),
      6,
    );
    await tester.tap(find.text('OFERTAR CARONA'));
    expect(toques, 1);
  });

  for (final estilo in [
    EstiloBotaoAcaoHome.principal,
    EstiloBotaoAcaoHome.secundario,
  ]) {
    final principal = estilo == EstiloBotaoAcaoHome.principal;
    final texto = principal ? 'Buscar carona' : 'Oferecer carona';
    final icone = principal ? Icons.search : Icons.directions_car_outlined;

    testWidgets('$estilo tem aparencia e acao corretas', (tester) async {
      var toques = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotaoAcaoHome(
              texto: texto,
              icone: icone,
              estilo: estilo,
              onPressed: () => toques++,
            ),
          ),
        ),
      );
      final controle = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate(
          (widget) =>
              principal ? widget is ElevatedButton : widget is OutlinedButton,
        ),
      );
      expect(tester.widget<Icon>(find.byIcon(icone)).size, 22);
      expect(
        controle.style?.minimumSize?.resolve({})?.height,
        principal ? 54 : 52,
      );
      if (principal) {
        expect(controle.style?.backgroundColor?.resolve({}), AppColors.primary);
        expect(controle.style?.elevation?.resolve({}), 0);
      } else {
        expect(controle.style?.side?.resolve({})?.color, AppColors.primary);
      }
      await tester.tap(find.text(texto));
      expect(toques, 1);
    });

    testWidgets('$estilo desabilitado nao dispara acao', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotaoAcaoHome(
              texto: texto,
              icone: icone,
              estilo: estilo,
              onPressed: null,
            ),
          ),
        ),
      );
      final controle = tester.widget<ButtonStyleButton>(
        find.byWidgetPredicate(
          (widget) =>
              principal ? widget is ElevatedButton : widget is OutlinedButton,
        ),
      );
      expect(controle.onPressed, isNull);
      await tester.tap(find.text(texto));
      expect(tester.takeException(), isNull);
    });

    for (final escala in [1.0, 1.5, 2.0]) {
      testWidgets('$estilo cabe em tela de 320 com fonte $escala', (
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
              ).copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: BotaoAcaoHome(
                  texto: texto,
                  icone: icone,
                  estilo: estilo,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        final botao = tester.getRect(find.byType(BotaoAcaoHome));
        final rotulo = tester.getRect(find.text(texto));
        expect(rotulo.left, greaterThanOrEqualTo(botao.left));
        expect(rotulo.right, lessThanOrEqualTo(botao.right));
        expect(rotulo.top, greaterThanOrEqualTo(botao.top));
        expect(rotulo.bottom, lessThanOrEqualTo(botao.bottom));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
