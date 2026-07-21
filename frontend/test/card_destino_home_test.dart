import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';

void main() {
  testWidgets('exibe o destino e responde ao toque', (tester) async {
    var tocou = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDestinoHome(
            destino: 'UniSalesiano - Aracatuba',
            onTap: () {
              tocou = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('UniSalesiano - Aracatuba'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byType(CardDestinoHome));

    expect(tocou, isTrue);
  });
}
