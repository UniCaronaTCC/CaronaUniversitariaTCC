import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/barra_navegacao_home.dart';

void main() {
  testWidgets('exibe Chat no lugar de Buscar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(bottomNavigationBar: BarraNavegacaoHome()),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.text('Buscar'), findsNothing);
  });
}
