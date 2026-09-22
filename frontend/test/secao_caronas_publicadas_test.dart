import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/widgets/secao_caronas_publicadas.dart';

void main() {
  testWidgets('mostra até duas próximas caronas e permite gerenciar', (
    tester,
  ) async {
    final caronas = [
      _carona(1, 'Campus A'),
      _carona(2, 'Campus B'),
      _carona(3, 'Campus C'),
    ];
    Carona? selecionada;
    Carona? editada;
    var abriuTodas = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecaoCaronasPublicadas(
              caronas: caronas,
              carregando: false,
              mensagemErro: null,
              onTentarNovamente: () {},
              onVerTodas: () => abriuTodas = true,
              onAbrirCarona: (carona) => selecionada = carona,
              onEditarCarona: (carona) => editada = carona,
              onCancelarCarona: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Suas próximas caronas'), findsOneWidget);
    expect(find.text('Campus A'), findsOneWidget);
    expect(find.text('Campus B'), findsOneWidget);
    expect(find.text('Campus C'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('card-carona-1')));
    expect(selecionada?.id, 1);

    await tester.tap(find.text('Ver todas'));
    expect(abriuTodas, isTrue);

    await tester.tap(find.byKey(const ValueKey('menu-carona-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(editada?.id, 1);
  });
}

Carona _carona(int id, String destino) {
  return Carona(
    id: id,
    origem: 'Centro',
    destino: destino,
    dataInicio: DateTime(2026, 10, id),
    horario: '19:00:00',
    vagas: 2,
    valor: 5,
    recorrente: false,
    diasSemana: const [],
    idMotorista: 10,
    motorista: 'João',
  );
}
