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

  testWidgets('barra superior exibe seta e volta para a tela anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: BarraSuperiorPadrao(titulo: 'Destino'),
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Destino'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Abrir'), findsOneWidget);
  });
}
