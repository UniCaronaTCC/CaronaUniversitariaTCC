import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/instituicao.dart';
import 'package:uni_carona/widgets/campo_busca_instituicao.dart';

void main() {
  testWidgets('permite selecionar uma instituição encontrada', (tester) async {
    Instituicao? selecionada;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampoBuscaInstituicao(
            valorInicial: '',
            buscarInstituicoes: (termo) async => const [
              Instituicao(
                id: 1,
                nome: 'Centro Universitário Salesiano',
                sigla: 'UNISALESIANO',
                campus: 'Araçatuba',
                municipio: 'Araçatuba',
                uf: 'SP',
              ),
            ],
            onChanged: (instituicao) => selecionada = instituicao,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'unisalesiano');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Campus Araçatuba - Araçatuba/SP'), findsOneWidget);

    await tester.tap(find.textContaining('Centro Universitário Salesiano'));
    await tester.pumpAndSettle();

    expect(selecionada?.id, 1);
    expect(selecionada?.campus, 'Araçatuba');
    expect(find.text('Centro Universitário Salesiano'), findsOneWidget);
  });
}
