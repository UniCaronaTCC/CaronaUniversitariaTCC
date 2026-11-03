import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/inicializacao/tela_abertura.dart';

Future<void> abrir(
  WidgetTester tester,
  Future<void> Function() inicializar, {
  GlobalKey<NavigatorState>? navegador,
  bool reduzir = false,
  bool leitor = false,
  double escala = 1,
  WidgetBuilder? destino,
}) => tester.pumpWidget(
  MaterialApp(
    navigatorKey: navegador,
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduzir,
        accessibleNavigation: leitor,
        textScaler: TextScaler.linear(escala),
      ),
      child: child!,
    ),
    home: TelaAbertura(
      inicializar: inicializar,
      construirDestino:
          destino ?? (_) => const Scaffold(body: Text('Destino pronto')),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontes = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Bold.ttf'));
    await fontes.load();
  });
  testWidgets('primeiro quadro roxo existe antes de iniciar os servicos', (
    tester,
  ) async {
    final pendente = Completer<void>();
    var chamadas = 0;
    await abrir(tester, () {
      chamadas++;
      expect(find.byKey(const ValueKey('tela-abertura')), findsOneWidget);
      expect(find.byKey(const ValueKey('logo-abertura')), findsOneWidget);
      return pendente.future;
    });
    expect(chamadas, 1);
    expect(
      tester
          .widget<Scaffold>(find.byKey(const ValueKey('tela-abertura')))
          .backgroundColor,
      AppColors.primary,
    );
    expect(find.text('BuscaEu'), findsOneWidget);
    expect(find.text('Carregando...'), findsOneWidget);
    expect(find.text('Destino pronto'), findsNothing);
    pendente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destino pronto'), findsOneWidget);
  });

  testWidgets('reconstrucoes nao reiniciam a operacao nem antecipam destino', (
    tester,
  ) async {
    final pendente = Completer<void>();
    var chamadas = 0;
    var destinos = 0;
    Future<void> inicializar() {
      chamadas++;
      return pendente.future;
    }

    Widget destino(BuildContext _) {
      destinos++;
      return const Scaffold(body: Text('Pronto'));
    }

    await abrir(tester, inicializar, destino: destino);
    await abrir(tester, inicializar, destino: destino, escala: 1.5);
    await tester.pump(const Duration(milliseconds: 500));
    expect(chamadas, 1);
    expect(destinos, 0);
    pendente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pronto'), findsOneWidget);
    expect(chamadas, 1);
    expect(destinos, greaterThan(0));
  });

  testWidgets('inicio rapido nao espera a animacao nem acrescenta atraso', (
    tester,
  ) async {
    await abrir(tester, () async {});
    await tester.pump();
    expect(find.text('Destino pronto'), findsOneWidget);
    expect(find.byKey(const ValueKey('tela-abertura')), findsNothing);
  });

  testWidgets('destino e escolhido uma vez mesmo apos reconstruir a abertura', (
    tester,
  ) async {
    var chamadas = 0;
    var destinos = 0;
    var nome = 'Destino inicial';
    Future<void> inicializar() async {
      chamadas++;
    }

    Widget construir(BuildContext _) {
      destinos++;
      return Scaffold(body: Text(nome));
    }

    await abrir(tester, inicializar, destino: construir);
    await tester.pumpAndSettle();
    nome = 'Outro destino';
    await abrir(tester, inicializar, destino: construir, escala: 1.5);
    await tester.pumpAndSettle();
    expect(find.text('Destino inicial'), findsOneWidget);
    expect(find.text('Outro destino'), findsNothing);
    expect(chamadas, 1);
    expect(destinos, 1);
  });

  for (final sincrona in [false, true]) {
    testWidgets(
      'falha de inicializacao e visivel sem repetir servicos sincrona=$sincrona',
      (tester) async {
        var chamadas = 0;
        await abrir(tester, () {
          chamadas++;
          if (sincrona) {
            throw StateError('Detalhes internos nao devem aparecer');
          }
          return Future.error(
            StateError('Detalhes internos nao devem aparecer'),
          );
        });
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Não foi possível iniciar o aplicativo.'),
          findsOneWidget,
        );
        expect(find.textContaining('Feche e abra o BuscaEu'), findsOneWidget);
        expect(find.textContaining('Detalhes internos'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Destino pronto'), findsNothing);
        await tester.pump(const Duration(minutes: 2));
        expect(chamadas, 1);
        expect(find.textContaining('Não foi possível iniciar'), findsOneWidget);
      },
    );
  }

  testWidgets('demora avisa sem cancelar sessao nem iniciar outra operacao', (
    tester,
  ) async {
    final pendente = Completer<void>();
    var chamadas = 0;
    await abrir(tester, () {
      chamadas++;
      return pendente.future;
    });
    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Carregando...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Está demorando mais que o esperado.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(chamadas, 1);
    expect(find.text('Destino pronto'), findsNothing);
    pendente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destino pronto'), findsOneWidget);
    expect(chamadas, 1);
  });

  for (final falhar in [false, true]) {
    testWidgets(
      'resposta apos descarte nao atualiza nem navega falhar=$falhar',
      (tester) async {
        final pendente = Completer<void>();
        await abrir(tester, () => pendente.future);
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Outra raiz'))),
        );
        if (falhar) {
          pendente.completeError(StateError('Falha atrasada'));
        } else {
          pendente.complete();
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 1));
        expect(find.text('Outra raiz'), findsOneWidget);
        expect(find.text('Destino pronto'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('suspender e retomar nao duplica inicializacao', (tester) async {
    final pendente = Completer<void>();
    var chamadas = 0;
    await abrir(tester, () {
      chamadas++;
      return pendente.future;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 500));
    expect(chamadas, 1);
    pendente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destino pronto'), findsOneWidget);
  });

  testWidgets('conclusao nao fecha outra rota aberta durante a espera', (
    tester,
  ) async {
    final pendente = Completer<void>();
    final navegador = GlobalKey<NavigatorState>();
    await abrir(tester, () => pendente.future, navegador: navegador);
    unawaited(
      navegador.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra rota')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    pendente.complete();
    await tester.pumpAndSettle();
    expect(find.text('Outra rota'), findsOneWidget);
    navegador.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Destino pronto'), findsOneWidget);
  });

  for (final acessibilidade in ['reduzir movimento', 'leitor de tela']) {
    testWidgets('$acessibilidade evita animacao continua e mantem mensagem', (
      tester,
    ) async {
      final pendente = Completer<void>();
      await abrir(
        tester,
        () => pendente.future,
        reduzir: acessibilidade == 'reduzir movimento',
        leitor: acessibilidade == 'leitor de tela',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Carregando...'), findsOneWidget);
      final semantica = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Carregando...'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semantica.properties.liveRegion, isTrue);
      pendente.complete();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('marca tem entrada discreta enquanto o carregamento e real', (
    tester,
  ) async {
    final pendente = Completer<void>();
    await abrir(tester, () => pendente.future);
    final transicao = find.ancestor(
      of: find.byKey(const ValueKey('logo-abertura')),
      matching: find.byType(ScaleTransition),
    );
    expect(
      tester.widget<ScaleTransition>(transicao).scale.value,
      closeTo(.97, .001),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final meio = tester.widget<ScaleTransition>(transicao).scale.value;
    expect(meio, greaterThan(.97));
    expect(meio, lessThan(1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<ScaleTransition>(transicao).scale.value, 1);
    expect(find.text('Destino pronto'), findsNothing);
    pendente.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('icones do sistema claros na abertura e escuros no destino', (
    tester,
  ) async {
    final pendente = Completer<void>();
    await abrir(tester, () => pendente.future);
    final anotacao = find.byType(AnnotatedRegion<SystemUiOverlayStyle>);
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(anotacao.last)
          .value
          .statusBarIconBrightness,
      Brightness.light,
    );
    pendente.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(anotacao.last)
          .value
          .statusBarIconBrightness,
      Brightness.dark,
    );
  });

  for (final caso in [
    (tamanho: const Size(390, 844), escala: 1.0),
    (tamanho: const Size(320, 640), escala: 1.8),
    (tamanho: const Size(320, 640), escala: 3.0),
    (tamanho: const Size(700, 360), escala: 1.8),
  ]) {
    testWidgets('abertura cabe em ${caso.tamanho} com fonte ${caso.escala}', (
      tester,
    ) async {
      tester.view.physicalSize = caso.tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pendente = Completer<void>();
      await abrir(tester, () => pendente.future, escala: caso.escala);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Carregando...'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Está demorando mais'));
      expect(tester.takeException(), isNull);
      pendente.complete();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('renderiza fundo roxo e logo branca com pixels reais', (
    tester,
  ) async {
    final pendente = Completer<void>();
    const chave = ValueKey('captura-abertura');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: chave,
          child: TelaAbertura(
            inicializar: () => pendente.future,
            construirDestino: (_) => const Scaffold(body: Text('Pronto')),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/imagens/simbolo_buscaeu_branco.png'),
        tester.element(find.byKey(chave)),
      );
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    final limite = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(chave),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('logo-abertura'))).dx,
      closeTo(195, .5),
    );
    expect(tester.getCenter(find.text('BuscaEu')).dx, closeTo(195, .5));
    await tester.runAsync(() async {
      final imagem = await limite.toImage();
      try {
        final dados = (await imagem.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var roxos = 0;
        var brancos = 0;
        for (var i = 0; i < dados.length; i += 4) {
          if (dados[i] == 143 && dados[i + 1] == 22 && dados[i + 2] == 217) {
            roxos++;
          }
          if (dados[i] > 245 && dados[i + 1] > 245 && dados[i + 2] > 245) {
            brancos++;
          }
        }
        expect(roxos, greaterThan(imagem.width * imagem.height * .8));
        expect(brancos, greaterThan(4000));
        const pasta = String.fromEnvironment('ABERTURA_QA_DIR');
        if (pasta.isNotEmpty) {
          final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
          await Directory(pasta).create(recursive: true);
          await File(
            '$pasta/abertura-390.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        }
      } finally {
        imagem.dispose();
      }
    });
    pendente.complete();
    await tester.pumpAndSettle();
  });
}
