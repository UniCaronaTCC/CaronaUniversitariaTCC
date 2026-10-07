import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/home/verificacao_cnh.dart';

void main() {
  testWidgets('abre CNH pelo perfil e atualiza os dados ao concluir', (
    tester,
  ) async {
    var consultas = 0;
    final perfil = {
      'id': 1,
      'nome': 'João',
      'statusVerificacaoCnh': 'APROVADA',
      'cnhCategoria': 'B',
      'cnhValidade': '2099-10-07',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: PerfilTela(
          carregarPerfil: () async {
            consultas++;
            return {'sucesso': true, 'dados': perfil};
          },
          carregarAvaliacoes: (_, _) async => {
            'sucesso': true,
            'dados': {'media': 0, 'total': 0},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CNH conferida'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CNH conferida'));
    await tester.pumpAndSettle();
    expect(find.byType(VerificacaoCnhTela), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(VerificacaoCnhTela), findsNothing);
    expect(consultas, 3);
    expect(find.textContaining('Categoria B'), findsOneWidget);
  });
}
