import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

void main() {
  Future<BuildContext> montar(WidgetTester tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              contexto = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return contexto;
  }

  for (final tipo in TipoAviso.values) {
    testWidgets('preserva texto e tipo $tipo sem definir aparencia', (
      tester,
    ) async {
      final contexto = await montar(tester);
      final controle = AvisoApp.mostrar(contexto, 'Mensagem atual', tipo: tipo);
      expect(controle, isNotNull);
      await tester.pumpAndSettle();
      expect(find.text('Mensagem atual'), findsOneWidget);
      expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, tipo);
      final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
      const padrao = SnackBar(content: Text('Mensagem atual'));
      expect(aviso.duration, padrao.duration);
      expect(aviso.backgroundColor, padrao.backgroundColor);
      expect(aviso.behavior, padrao.behavior);
      expect(aviso.shape, padrao.shape);
      expect(aviso.elevation, padrao.elevation);
      expect(aviso.margin, padrao.margin);
      expect(aviso.padding, padrao.padding);
      expect(aviso.showCloseIcon, padrao.showCloseIcon);
      expect(tester.widget<Text>(find.text('Mensagem atual')).style, isNull);
    });
  }

  testWidgets('tipo padrao e informacao', (tester) async {
    final contexto = await montar(tester);
    AvisoApp.mostrar(contexto, 'Informacao');
    await tester.pumpAndSettle();
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.informacao,
    );
  });

  testWidgets('preserva acao ATUALIZAR e o encerramento do SnackBar', (
    tester,
  ) async {
    final contexto = await montar(tester);
    var chamadas = 0;
    final acao = SnackBarAction(
      label: 'ATUALIZAR',
      onPressed: () => chamadas++,
    );
    final controle = AvisoApp.mostrar(
      contexto,
      'Atualize o percurso',
      tipo: TipoAviso.atencao,
      acao: acao,
    )!;
    await tester.pumpAndSettle();
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).action, same(acao));
    await tester.tap(find.text('ATUALIZAR'));
    await tester.pumpAndSettle();
    expect(chamadas, 1);
    expect(await controle.closed, SnackBarClosedReason.action);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('aceita duracao opcional e mantem timeout do framework', (
    tester,
  ) async {
    final contexto = await montar(tester);
    final controle = AvisoApp.mostrar(
      contexto,
      'Aviso curto',
      duracao: const Duration(seconds: 1),
    )!;
    await tester.pumpAndSettle();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 1),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(await controle.closed, SnackBarClosedReason.timeout);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('preserva a fila em vez de descartar avisos anteriores', (
    tester,
  ) async {
    final contexto = await montar(tester);
    final primeiro = AvisoApp.mostrar(contexto, 'Primeiro')!;
    AvisoApp.mostrar(contexto, 'Segundo');
    await tester.pumpAndSettle();
    expect(find.text('Primeiro'), findsOneWidget);
    expect(find.text('Segundo'), findsNothing);
    primeiro.close();
    await tester.pumpAndSettle();
    expect(find.text('Primeiro'), findsNothing);
    expect(find.text('Segundo'), findsOneWidget);
  });

  testWidgets('ignora contexto desmontado sem procurar ScaffoldMessenger', (
    tester,
  ) async {
    final contexto = await montar(tester);
    await tester.pumpWidget(const SizedBox());
    expect(contexto.mounted, isFalse);
    expect(AvisoApp.mostrar(contexto, 'Resposta tardia'), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aviso continua visivel ao substituir a tela', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                AvisoApp.mostrar(
                  context,
                  'Operacao concluida',
                  tipo: TipoAviso.sucesso,
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Proxima tela')),
                  ),
                );
              },
              child: const Text('Continuar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Proxima tela'), findsOneWidget);
    expect(find.text('Operacao concluida'), findsOneWidget);
    expect(
      tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
      TipoAviso.sucesso,
    );
    expect(tester.takeException(), isNull);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
      'texto com teclado aberto e fonte $escala cabe sem estilo novo',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late BuildContext contexto;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(escala),
                viewInsets: const EdgeInsets.only(bottom: 300),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  contexto = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        AvisoApp.mostrar(
          contexto,
          'Confira os dados da carona e tente novamente.',
          tipo: TipoAviso.erro,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Confira os dados da carona e tente novamente.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
