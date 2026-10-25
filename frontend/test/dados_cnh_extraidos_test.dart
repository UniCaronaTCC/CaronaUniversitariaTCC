import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/dados_cnh_extraidos.dart';

void main() {
  testWidgets('mostra nome e registro lidos em tela estreita', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DadosCnhExtraidos(
            carregar: () async => {
              'nome': 'MARIA CLARA SILVA',
              'registro': '12345678901',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nome: MARIA CLARA SILVA'), findsOneWidget);
    expect(find.text('Registro da CNH: 12345678901'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('campos não lidos são informados sem pedir nome digitado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DadosCnhExtraidos(
            carregar: () async => {'nome': null, 'registro': null},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      find.textContaining('Não identificado nesta leitura'),
      findsNWidgets(2),
    );
  });
}
