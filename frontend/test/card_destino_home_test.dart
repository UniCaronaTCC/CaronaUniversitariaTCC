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

  testWidgets('separa nome e endereco sem cortar o texto', (tester) async {
    const endereco = 'Rodovia Senador Teotonio Vilela, 3821 - Aracatuba, SP';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDestinoHome(
            destino: 'UniSALESIANO - $endereco',
            nome: 'UniSALESIANO',
            endereco: endereco,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Seu destino'), findsOneWidget);
    expect(find.text('UniSALESIANO'), findsOneWidget);
    expect(find.text(endereco), findsOneWidget);
    expect(tester.widget<Text>(find.text(endereco)).maxLines, isNull);
    expect(
      tester.widget<Text>(find.text(endereco)).overflow,
      isNot(TextOverflow.ellipsis),
    );
    expect(
      tester.getTopLeft(find.text(endereco)).dy,
      greaterThan(tester.getTopLeft(find.text('UniSALESIANO')).dy),
    );
  });

  testWidgets('sem nome conhecido preserva endereco e seus hifens', (
    tester,
  ) async {
    const endereco = 'Avenida Brasil - lado par, 100 - Centro - Aracatuba, SP';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDestinoHome(
            destino: endereco,
            endereco: endereco,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text(endereco), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nome vazio nao esconde endereco nem duplica texto', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDestinoHome(
            destino: 'Rua A, 10',
            nome: '  ',
            endereco: 'Rua A, 10',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Rua A, 10'), findsOneWidget);
  });

  testWidgets('destino ainda nao escolhido continua clicavel', (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardDestinoHome(
            destino: 'Escolha seu destino',
            onTap: () => toques++,
          ),
        ),
      ),
    );
    expect(find.text('Escolha seu destino'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(toques, 1);
  });

  for (final escala in [1.0, 1.5, 2.0]) {
    testWidgets('texto longo cabe em tela estreita com escala $escala', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const nome =
          'Centro Universitario com Nome Muito Longo - Campus Aracatuba';
      const endereco =
          'Rodovia Senador Teotonio Vilela, 3821, Bairro Universitario, Aracatuba, Sao Paulo';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: CardDestinoHome(
                destino: '$nome - $endereco',
                nome: nome,
                endereco: endereco,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text(nome), findsOneWidget);
      expect(find.text(endereco), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text(nome)).dy,
        lessThan(tester.getTopLeft(find.text(endereco)).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
