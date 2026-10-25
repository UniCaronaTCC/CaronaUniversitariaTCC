import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/widgets/dialogo_veiculo.dart';

const veiculo = {
  'id': 7,
  'modelo': 'Honda Civic',
  'cor': 'Prata',
  'placa': 'ABC1D23',
};
Map<String, dynamic> sucesso() => {'sucesso': true, 'dados': veiculo};

Future<void> abrir(
  WidgetTester tester, {
  Map<String, dynamic> atual = const {},
  required Future<Map<String, dynamic>> Function(String, String, String) salvar,
  double escala = 1,
  EdgeInsets teclado = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala), viewInsets: teclado),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<Map<String, dynamic>>(
              context: context,
              barrierDismissible: false,
              builder: (_) => DialogoVeiculo(veiculo: atual, salvar: salvar),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> salvar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Salvar'));
  await tester.tap(find.text('Salvar'));
  await tester.pump();
}

void main() {
  testWidgets('campos vazios mostram erros locais sem enviar', (tester) async {
    var chamadas = 0;
    await abrir(
      tester,
      salvar: (_, _, _) async {
        chamadas++;
        return sucesso();
      },
    );
    await salvar(tester);
    expect(chamadas, 0);
    expect(
      find.text('Informe a marca e o modelo v\u00e1lidos'),
      findsOneWidget,
    );
    expect(find.text('Selecione a cor do ve\u00edculo'), findsOneWidget);
    expect(find.text('Informe uma placa v\u00e1lida'), findsOneWidget);
  });

  testWidgets('cadastra com cor selecionavel e placa antiga normalizada', (
    tester,
  ) async {
    List<String>? enviado;
    await abrir(
      tester,
      salvar: (modelo, cor, placa) async {
        enviado = [modelo, cor, placa];
        return sucesso();
      },
    );
    await tester.enterText(
      find.byKey(const Key('veiculo-modelo')),
      '  Honda   Civic  ',
    );
    await tester.tap(find.byKey(const Key('veiculo-cor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branco').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('veiculo-placa')), 'abc-1234');
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(enviado, ['Honda Civic', 'Branco', 'ABC1234']);
    expect(find.byType(DialogoVeiculo), findsNothing);
  });

  testWidgets('edita e preserva dados existentes inclusive cor personalizada', (
    tester,
  ) async {
    List<String>? enviado;
    await abrir(
      tester,
      atual: {...veiculo, 'cor': 'Azul escuro'},
      salvar: (modelo, cor, placa) async {
        enviado = [modelo, cor, placa];
        return sucesso();
      },
    );
    expect(find.text('Editar ve\u00edculo'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-outra-cor')))
          .controller!
          .text,
      'Azul escuro',
    );
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(enviado, ['Honda Civic', 'Azul escuro', 'ABC1D23']);
  });

  testWidgets('bloqueia envio repetido, campos e voltar enquanto aguarda', (
    tester,
  ) async {
    final pendente = Completer<Map<String, dynamic>>();
    var chamadas = 0;
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) {
        chamadas++;
        return pendente.future;
      },
    );
    await salvar(tester);
    await tester.pump();
    expect(chamadas, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('veiculo-salvar')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(DialogoVeiculo), findsOneWidget);
    pendente.complete(sucesso());
    await tester.pumpAndSettle();
    expect(find.byType(DialogoVeiculo), findsNothing);
  });

  testWidgets('falha mantem formulario e dados e permite nova tentativa', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) async => ++chamadas == 1
          ? {'sucesso': false, 'mensagem': 'Servidor indisponivel'}
          : sucesso(),
    );
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Servidor indisponivel'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
          .controller!
          .text,
      'Honda Civic',
    );
    expect(find.text('ABC1D23'), findsOneWidget);
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(find.byType(DialogoVeiculo), findsNothing);
  });

  testWidgets('erro de placa aparece no campo e e limpo ao corrigir', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) async => ++chamadas == 1
          ? {
              'sucesso': false,
              'campos': {'placa': 'Placa ja cadastrada'},
            }
          : sucesso(),
    );
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(find.text('Placa ja cadastrada'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('veiculo-placa')), 'XYZ9Z99');
    await tester.pumpAndSettle();
    expect(find.text('Placa ja cadastrada'), findsNothing);
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(chamadas, 2);
  });

  testWidgets('recusa pontuacao no modelo e numeros na cor', (tester) async {
    var chamadas = 0;
    await abrir(
      tester,
      atual: {...veiculo, 'modelo': '@@', 'cor': '99'},
      salvar: (_, _, _) async {
        chamadas++;
        return sucesso();
      },
    );
    await salvar(tester);
    expect(chamadas, 0);
    expect(
      find.text('Informe a marca e o modelo v\u00e1lidos'),
      findsOneWidget,
    );
    expect(find.text('Informe uma cor v\u00e1lida'), findsOneWidget);
  });

  testWidgets('excecao e resposta incompleta nao fecham nem apagam os dados', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) async {
        if (++chamadas == 1) throw StateError('rede');
        return {'sucesso': true};
      },
    );
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Confira a conex\u00e3o'), findsOneWidget);
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DialogoVeiculo), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
          .controller!
          .text,
      'Honda Civic',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bloqueio por passageiros mantem formulario e dados preenchidos', (
    tester,
  ) async {
    const mensagem =
        'Voc\u00ea tem caronas com passageiros confirmados. Conclua ou cancele essas caronas antes de alterar o ve\u00edculo';
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) async => {'sucesso': false, 'mensagem': mensagem},
    );
    expect(
      find.text(
        'As caronas j\u00e1 publicadas mant\u00eam o ve\u00edculo informado.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('veiculo-modelo')),
      'Outro modelo',
    );
    await salvar(tester);
    await tester.pumpAndSettle();
    expect(find.text(mensagem), findsOneWidget);
    expect(find.byType(DialogoVeiculo), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
          .controller!
          .text,
      'Outro modelo',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar nao salva e reabrir restaura o cadastro original', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      atual: veiculo,
      salvar: (_, _, _) async {
        chamadas++;
        return sucesso();
      },
    );
    await tester.enterText(
      find.byKey(const Key('veiculo-modelo')),
      'Outro modelo',
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('veiculo-modelo')))
          .controller!
          .text,
      'Honda Civic',
    );
    expect(chamadas, 0);
  });

  testWidgets(
    'tela estreita com fonte grande e teclado permite salvar e exibir erro',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(
        tester,
        atual: {...veiculo, 'cor': 'Azul escuro'},
        escala: 1.5,
        teclado: const EdgeInsets.only(bottom: 240),
        salvar: (_, _, _) async => {
          'sucesso': false,
          'mensagem':
              'N\u00e3o foi poss\u00edvel salvar o ve\u00edculo. Confira a conex\u00e3o e tente novamente.',
        },
      );
      await salvar(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Confira a conex\u00e3o'));
      expect(find.byType(DialogoVeiculo), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
