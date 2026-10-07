import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/ofertar_carona.dart';
import 'package:uni_carona/home/verificacao_cnh.dart';
import 'package:uni_carona/widgets/formulario_ofertar_carona.dart';

void main() {
  testWidgets('entrada de verificação permite rolagem em paisagem', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OfertarCaronaTela(
          carregarPerfil: () async => {
            'sucesso': true,
            'dados': <String, dynamic>{},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Verificar CNH'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Verificar CNH'), findsOneWidget);
  });
  testWidgets('direciona usuário sem CNH ao fluxo de verificação', (
    tester,
  ) async {
    Future<Map<String, dynamic>> perfil() async => {
      'sucesso': true,
      'dados': {
        'statusVerificacaoCnh': 'NAO_ENVIADA',
        'veiculo': {'modelo': 'Carro'},
      },
    };
    await tester.pumpWidget(
      MaterialApp(home: OfertarCaronaTela(carregarPerfil: perfil)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FormularioOfertarCarona), findsNothing);
    await tester.tap(find.text('Verificar CNH'));
    await tester.pumpAndSettle();
    expect(find.byType(VerificacaoCnhTela), findsOneWidget);
  });

  testWidgets(
    'CNH vigente libera o formulário com o veículo do perfil atualizado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfertarCaronaTela(
            carregarPerfil: () async => {
              'sucesso': true,
              'dados': {
                'statusVerificacaoCnh': 'APROVADA',
                'cnhCategoria': 'B',
                'cnhValidade': '2099-10-07',
                'veiculo': {'modelo': 'Carro'},
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FormularioOfertarCarona), findsOneWidget);
      expect(
        tester
            .widget<FormularioOfertarCarona>(
              find.byType(FormularioOfertarCarona),
            )
            .possuiVeiculo,
        isTrue,
      );
    },
  );

  testWidgets('falha na consulta mostra ação para tentar novamente', (
    tester,
  ) async {
    var chamadas = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OfertarCaronaTela(
          carregarPerfil: () async {
            chamadas++;
            return {'sucesso': false, 'mensagem': 'Sem conexão'};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem conexão'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(find.byType(FormularioOfertarCarona), findsNothing);
  });
}
