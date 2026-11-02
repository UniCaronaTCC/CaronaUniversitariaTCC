import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_colors.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

void main() {
  Future<BuildContext> montar(
    WidgetTester tester, {
    bool leitorDeTela = false,
    bool reduzirAnimacoes = false,
    ThemeData? tema,
  }) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        theme: tema ?? AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: leitorDeTela,
            disableAnimations: reduzirAnimacoes,
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
    return contexto;
  }

  const estilos = {
    TipoAviso.sucesso: (
      fundo: AppColors.primary,
      texto: Colors.white,
      icone: Icons.check_circle_outline_rounded,
      rotulo: 'Sucesso',
      segundos: 2,
    ),
    TipoAviso.informacao: (
      fundo: Color(0xFFF2E8FC),
      texto: Color(0xFF57108A),
      icone: Icons.info_outline_rounded,
      rotulo: 'Informação',
      segundos: 4,
    ),
    TipoAviso.atencao: (
      fundo: Color(0xFFFFF3D6),
      texto: Color(0xFF754900),
      icone: Icons.warning_amber_rounded,
      rotulo: 'Atenção',
      segundos: 4,
    ),
    TipoAviso.erro: (
      fundo: Color(0xFFC62828),
      texto: Colors.white,
      icone: Icons.error_outline_rounded,
      rotulo: 'Erro',
      segundos: 5,
    ),
  };

  for (final entrada in estilos.entries) {
    final tipo = entrada.key;
    final estilo = entrada.value;
    testWidgets(
      'aviso $tipo tem visual, contraste, semantica e tempo corretos',
      (tester) async {
        final contexto = await montar(tester);
        final controle = AvisoApp.mostrar(
          contexto,
          'Mensagem atual',
          tipo: tipo,
        );
        expect(controle, isNotNull);
        await tester.pumpAndSettle();
        expect(find.text('Mensagem atual'), findsOneWidget);
        expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, tipo);
        final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(aviso.duration, Duration(seconds: estilo.segundos));
        expect(aviso.backgroundColor, Colors.transparent);
        final cartao = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AvisoApp),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(cartao.color, estilo.fundo);
        expect(cartao.elevation, 3);
        expect(cartao.borderRadius, BorderRadius.circular(8));
        expect(aviso.behavior, SnackBarBehavior.floating);
        expect(
          (aviso.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(8),
        );
        expect(aviso.elevation, 0);
        expect(aviso.clipBehavior, Clip.none);
        expect(aviso.margin, const EdgeInsets.fromLTRB(16, 8, 16, 12));
        expect(aviso.showCloseIcon, isFalse);
        expect(aviso.persist, isFalse);
        expect(aviso.dismissDirection, DismissDirection.down);
        expect(find.byIcon(estilo.icone), findsOneWidget);
        expect(find.byType(IconButton), findsNothing);
        final texto = tester.widget<Text>(find.text('Mensagem atual'));
        expect(texto.style!.color, estilo.texto);
        expect(texto.style!.letterSpacing, 0);
        expect(texto.maxLines, isNull);
        expect(texto.overflow, isNull);
        final fundo = estilo.fundo.computeLuminance();
        final frente = estilo.texto.computeLuminance();
        final contraste = fundo > frente
            ? (fundo + 0.05) / (frente + 0.05)
            : (frente + 0.05) / (fundo + 0.05);
        expect(contraste, greaterThanOrEqualTo(4.5));
        final semantica = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(AvisoApp),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantica.properties.label, '${estilo.rotulo}. Mensagem atual');
        expect(semantica.excludeSemantics, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('aviso $tipo fecha sozinho apenas depois do prazo', (
      tester,
    ) async {
      final contexto = await montar(tester);
      final controle = AvisoApp.mostrar(
        contexto,
        'Mensagem atual',
        tipo: tipo,
      )!;
      await tester.pumpAndSettle();
      await tester.pump(Duration(seconds: estilo.segundos - 1));
      expect(find.text('Mensagem atual'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Mensagem atual'), findsNothing);
      expect(await controle.closed, SnackBarClosedReason.timeout);
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
    final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
    final botao = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(botao.onPressed, same(acao.onPressed));
    expect(botao.label, acao.label);
    expect(botao.textColor, estilos[TipoAviso.atencao]!.texto);
    expect(aviso.duration, const Duration(seconds: 8));
    expect(aviso.persist, isFalse);
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
      'texto com teclado aberto, barra inferior e fonte $escala cabe inteiro',
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
              bottomNavigationBar: const SizedBox(height: 64),
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
        final retangulo = tester.getRect(find.byType(SnackBar));
        expect(retangulo.bottom, lessThanOrEqualTo(844 - 300));
        expect(retangulo.left, greaterThanOrEqualTo(0));
        expect(retangulo.right, lessThanOrEqualTo(320));
      },
    );
  }

  testWidgets('aviso com acao tambem expira apos oito segundos', (
    tester,
  ) async {
    final contexto = await montar(tester);
    var chamadas = 0;
    final controle = AvisoApp.mostrar(
      contexto,
      'Atualize o percurso',
      acao: SnackBarAction(label: 'ATUALIZAR', onPressed: () => chamadas++),
    )!;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('ATUALIZAR'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(await controle.closed, SnackBarClosedReason.timeout);
    expect(chamadas, 0);
  });

  testWidgets('acao preserva chave, callback e cores explicitas', (
    tester,
  ) async {
    final contexto = await montar(tester);
    final acao = SnackBarAction(
      key: const ValueKey('acao-aviso'),
      label: 'TENTAR',
      onPressed: () {},
      textColor: Colors.black,
      disabledTextColor: Colors.grey,
      backgroundColor: Colors.white,
      disabledBackgroundColor: Colors.white70,
    );
    AvisoApp.mostrar(contexto, 'Tente novamente', acao: acao);
    await tester.pumpAndSettle();
    final nova = tester.widget<SnackBarAction>(find.byKey(acao.key!));
    expect(nova.onPressed, same(acao.onPressed));
    expect(nova.textColor, acao.textColor);
    expect(nova.disabledTextColor, acao.disabledTextColor);
    expect(nova.backgroundColor, acao.backgroundColor);
    expect(nova.disabledBackgroundColor, acao.disabledBackgroundColor);
  });

  testWidgets('mensagem longa recebe mais tempo sem truncar texto', (
    tester,
  ) async {
    final contexto = await montar(tester);
    const mensagem =
        'Carona atualizada com sucesso. Os passageiros confirmados '
        'continuam na viagem e podem consultar as informações atualizadas.';
    AvisoApp.mostrar(contexto, mensagem, tipo: TipoAviso.sucesso);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      greaterThan(const Duration(seconds: 2)),
    );
    expect(find.text(mensagem), findsOneWidget);
    expect(tester.widget<Text>(find.text(mensagem)).maxLines, isNull);
  });

  testWidgets('duracao explicita de um segundo e meio tem prioridade', (
    tester,
  ) async {
    final contexto = await montar(tester);
    const mensagem =
        'Carona atualizada com sucesso e passageiros informados '
        'sobre todos os detalhes desta operação.';
    AvisoApp.mostrar(
      contexto,
      mensagem,
      tipo: TipoAviso.sucesso,
      duracao: const Duration(milliseconds: 1500),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(milliseconds: 1500),
    );
  });

  testWidgets('entrada e saida usam o ciclo nativo de 360 e 240 ms', (
    tester,
  ) async {
    final contexto = await montar(tester);
    final controle = AvisoApp.mostrar(contexto, 'Salvo')!;
    await tester.pump();
    final animacao = tester.widget<SnackBar>(find.byType(SnackBar)).animation!;
    expect(
      (animacao as AnimationController).duration,
      const Duration(milliseconds: 360),
    );
    expect(animacao.reverseDuration, const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 100));
    expect(animacao.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(animacao.status, AnimationStatus.completed);
    final repouso = tester.widget<Transform>(
      find.byKey(const ValueKey('movimento-aviso')),
    );
    expect(repouso.transform.getTranslation().y, closeTo(0, 0.001));
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('escala-aviso')))
          .transform
          .entry(0, 0),
      1,
    );
    controle.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    expect(animacao.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('o cartao inteiro desliza e expande junto com a animacao', (
    tester,
  ) async {
    final contexto = await montar(tester);
    final controle = AvisoApp.mostrar(contexto, 'Salvo')!;
    await tester.pump();
    final movimento = find.byKey(const ValueKey('movimento-aviso'));
    final escala = find.byKey(const ValueKey('escala-aviso'));
    expect(
      tester.widget<Transform>(movimento).transform.getTranslation().y,
      28,
    );
    expect(tester.widget<Transform>(escala).transform.entry(0, 0), 0.94);
    expect(
      find.descendant(of: movimento, matching: find.byType(Material)),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      tester.widget<Transform>(movimento).transform.getTranslation().y,
      inExclusiveRange(0, 28),
    );
    expect(
      tester.widget<Transform>(escala).transform.entry(0, 0),
      inExclusiveRange(0.94, 1),
    );
    await tester.pumpAndSettle();
    controle.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.widget<Transform>(movimento).transform.getTranslation().y,
      greaterThan(0),
    );
    expect(tester.widget<Transform>(escala).transform.entry(0, 0), lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sucesso permanece ao voltar da publicacao para a tela anterior',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          AvisoApp.mostrar(
                            context,
                            'Carona criada com sucesso',
                            tipo: TipoAviso.sucesso,
                          );
                          Navigator.of(context).pop();
                        },
                        child: const Text('Publicar'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Ofertar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ofertar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(find.text('Publicar'), findsNothing);
      expect(find.text('Ofertar'), findsOneWidget);
      expect(find.text('Carona criada com sucesso'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Carona criada com sucesso'), findsNothing);
      expect(find.text('Ofertar'), findsOneWidget);
    },
  );

  for (final cenario in [
    (tamanho: const Size(320, 700), escala: 2.0, teclado: 300.0, acao: true),
    (tamanho: const Size(320, 700), escala: 3.0, teclado: 300.0, acao: false),
    (tamanho: const Size(700, 360), escala: 2.0, teclado: 0.0, acao: true),
  ]) {
    testWidgets('layout com aviso longo em $cenario', (tester) async {
      tester.view.physicalSize = cenario.tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext contexto;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(cenario.escala),
              viewInsets: EdgeInsets.only(bottom: cenario.teclado),
            ),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: const SizedBox(height: 64),
            body: Builder(
              builder: (context) {
                contexto = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      const mensagem =
          'Esta data pertence à programação. Para outra data, publique uma carona avulsa.';
      var chamadas = 0;
      final controle = AvisoApp.mostrar(
        contexto,
        mensagem,
        acao: cenario.acao
            ? SnackBarAction(label: 'ATUALIZAR', onPressed: () => chamadas++)
            : null,
      )!;
      await tester.pumpAndSettle();
      expect(find.text(mensagem), findsOneWidget);
      expect(tester.takeException(), isNull);
      final area = tester.getRect(find.byType(SnackBar));
      expect(area.top, greaterThanOrEqualTo(0));
      expect(
        area.bottom,
        lessThanOrEqualTo(cenario.tamanho.height - cenario.teclado),
      );
      final rolagem = find.descendant(
        of: find.byType(AvisoApp),
        matching: find.byType(SingleChildScrollView),
      );
      final estado = tester.state<ScrollableState>(
        find.descendant(of: rolagem, matching: find.byType(Scrollable)),
      );
      if (estado.position.maxScrollExtent > 0) {
        await tester.drag(rolagem, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(estado.position.pixels, greaterThan(0));
        expect(find.byType(SnackBar), findsOneWidget);
        estado.position.jumpTo(estado.position.maxScrollExtent);
        await tester.pump();
        expect(
          tester.getBottomRight(find.text(mensagem)).dy,
          lessThanOrEqualTo(tester.getBottomRight(rolagem).dy + 1),
        );
      }
      if (cenario.acao) {
        await tester.tap(find.text('ATUALIZAR'));
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(await controle.closed, SnackBarClosedReason.action);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final comAcao in [false, true]) {
    testWidgets('leitor de tela mantem aviso com acao=$comAcao ate dispensar', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      try {
        final contexto = await montar(tester, leitorDeTela: true);
        final controle = AvisoApp.mostrar(
          contexto,
          'Confira os dados',
          acao: comAcao
              ? SnackBarAction(label: 'ATUALIZAR', onPressed: () {})
              : null,
        )!;
        await tester.pumpAndSettle();
        final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(aviso.persist, isTrue);
        expect(find.byKey(const ValueKey('movimento-aviso')), findsNothing);
        expect(find.byKey(const ValueKey('escala-aviso')), findsNothing);
        expect(
          (aviso.animation! as AnimationController).duration,
          Duration.zero,
        );
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('Confira os dados'), findsOneWidget);
        final dispensar = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.onDismiss != null,
        );
        expect(dispensar, findsOneWidget);
        final node = tester.getSemantics(dispensar);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.dismiss),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(
            type: SemanticsAction.dismiss,
            nodeId: node.id,
            viewId: tester.view.viewId,
          ),
        );
        await tester.pumpAndSettle();
        expect(await controle.closed, SnackBarClosedReason.dismiss);
      } finally {
        semantica.dispose();
      }
    });
  }

  testWidgets(
    'preferencia de reduzir animacoes remove transicao mas nao timeout',
    (tester) async {
      final contexto = await montar(tester, reduzirAnimacoes: true);
      final controle = AvisoApp.mostrar(
        contexto,
        'Salvo',
        tipo: TipoAviso.sucesso,
      )!;
      await tester.pumpAndSettle();
      final aviso = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(find.byKey(const ValueKey('movimento-aviso')), findsNothing);
      expect(find.byKey(const ValueKey('escala-aviso')), findsNothing);
      expect((aviso.animation! as AnimationController).duration, Duration.zero);
      expect(aviso.persist, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(await controle.closed, SnackBarClosedReason.timeout);
    },
  );

  testWidgets('gesto para baixo dispensa aviso sem botao X', (tester) async {
    final contexto = await montar(tester);
    final controle = AvisoApp.mostrar(contexto, 'Salvo')!;
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnackBar), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(await controle.closed, SnackBarClosedReason.swipe);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('tema global nao impoe X nem altera avisos de outras telas', (
    tester,
  ) async {
    final contexto = await montar(
      tester,
      tema: AppTheme.lightTheme.copyWith(
        snackBarTheme: const SnackBarThemeData(showCloseIcon: true),
      ),
    );
    final controle = AvisoApp.mostrar(contexto, 'Novo aviso')!;
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);
    controle.close();
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      contexto,
    ).showSnackBar(const SnackBar(content: Text('Aviso antigo')));
    await tester.pumpAndSettle();
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).behavior, isNull);
    expect(find.byType(AvisoApp), findsNothing);
    expect(find.byType(IconButton), findsOneWidget);
  });
}
