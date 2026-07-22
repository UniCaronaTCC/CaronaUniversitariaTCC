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
            onTap: (index) {
              itemSelecionado = index;
            },
          ),
        ),
      ),
    );

    expect(find.text('Chat'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
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
          bottomNavigationBar: BarraNavegacaoHome(currentIndex: 2),
        ),
      ),
    );

    final barra = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );

    expect(barra.currentIndex, 2);
  });
}
