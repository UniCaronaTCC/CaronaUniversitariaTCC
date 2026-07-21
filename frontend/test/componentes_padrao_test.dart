import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/componentes_padrao.dart';

void main() {
  testWidgets('exibe o estado de carregamento', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EstadoConteudoPadrao(
          carregando: true,
          mensagem: 'Carregando caronas...',
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando caronas...'), findsOneWidget);
  });

  testWidgets('exibe mensagem e executa a acao', (tester) async {
    var pressionado = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EstadoConteudoPadrao(
          icone: Icons.cloud_off_outlined,
          mensagem: 'Erro ao carregar',
          textoBotao: 'Tentar novamente',
          onPressed: () {
            pressionado = true;
          },
        ),
      ),
    );

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(find.text('Erro ao carregar'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));

    expect(pressionado, isTrue);
  });
}
