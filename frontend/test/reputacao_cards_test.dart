import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/reputacao.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';
import 'package:uni_carona/widgets/card_carona_historico.dart';
import 'package:uni_carona/widgets/card_carona_publicada.dart';
import 'package:uni_carona/widgets/card_solicitacao_enviada.dart';
import 'package:uni_carona/widgets/card_solicitacao_recebida.dart';
import 'package:uni_carona/widgets/conteudo_detalhes_carona.dart';
import 'package:uni_carona/widgets/indicador_reputacao.dart';
import 'package:uni_carona/widgets/visual_buscaeu.dart';

import 'reputacao_test.dart' show caronaComReputacao, pedidoComReputacao;

const tipos = [
  'home',
  'busca',
  'publicada',
  'historico',
  'recebida',
  'enviada',
  'detalhes',
];
const avaliado = {'media': 4.8, 'total': 12};
const semAvaliacoes = {'media': 0, 'total': 0};

Widget criarCard(
  String tipo,
  Object? reputacao, {
  VoidCallback? onAbrir,
  VoidCallback? onAceitar,
  VoidCallback? onRecusar,
  VoidCallback? onPagar,
  bool nomeLongo = false,
}) {
  final jsonCarona = caronaComReputacao(reputacao);
  final jsonPedido = pedidoComReputacao(reputacao);
  if (nomeLongo) {
    const nome = 'Pessoa com nome e sobrenomes bastante extensos para o card';
    (jsonCarona['usuario'] as Map)['nome'] = nome;
    (jsonPedido['motorista'] as Map)['nome'] = nome;
    (jsonPedido['passageiro'] as Map)['nome'] = nome;
  }
  if (onPagar != null) jsonPedido['status'] = 'ACEITA';
  final carona = Carona.fromJson(jsonCarona);
  return switch (tipo) {
    'home' || 'busca' => CardCaronaDisponivel(
      carona: carona,
      visualHome: tipo == 'home',
      onTap: onAbrir,
    ),
    'publicada' => CardCaronaPublicada(carona: carona, onTap: onAbrir ?? () {}),
    'historico' => CardCaronaHistorico(carona: carona, onTap: onAbrir ?? () {}),
    'recebida' => CardSolicitacaoRecebida(
      solicitacao: SolicitacaoRecebida.fromJson(jsonPedido),
      processando: false,
      onAbrirDetalhes: onAbrir,
      onAceitar: onAceitar ?? () {},
      onRecusar: onRecusar ?? () {},
    ),
    'enviada' => CardSolicitacaoEnviada(
      solicitacao: SolicitacaoEnviada.fromJson(jsonPedido),
      onAbrirDetalhes: onAbrir,
      onPagarPix: onPagar,
    ),
    _ => ConteudoDetalhesCarona(carona: carona),
  };
}

Future<void> abrir(
  WidgetTester tester,
  Widget card, {
  double escala = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('captura-reputacao'),
        child: VisualBuscaEu(
          child: Scaffold(
            body: card is ConteudoDetalhesCarona
                ? card
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: card,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonte = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Bold.ttf'));
    await fonte.load();
    final icones = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icones.load();
  });

  for (final tipo in tipos) {
    for (final largura in [320.0, 412.0]) {
      for (final escala in [1.0, 1.8]) {
        for (final estado in ['avaliado', 'sem notas', 'indisponivel']) {
          testWidgets('$tipo: $estado, largura $largura, fonte $escala', (
            tester,
          ) async {
            tester.view.physicalSize = Size(largura, 850);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final resumo = switch (estado) {
              'avaliado' => avaliado,
              'sem notas' => semAvaliacoes,
              _ => null,
            };
            await abrir(tester, criarCard(tipo, resumo), escala: escala);
            expect(tester.takeException(), isNull);
            expect(
              find.text('4,8 / 5 · 12 avaliações'),
              estado == 'avaliado' ? findsOneWidget : findsNothing,
            );
            expect(
              find.text('Perfil ainda não avaliado'),
              estado == 'sem notas' ? findsOneWidget : findsNothing,
            );
            expect(find.textContaining('0,0 / 5'), findsNothing);
          });
        }
      }
    }

    testWidgets('$tipo: nome longo e fonte ampliada nao cortam a reputacao', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(
        tester,
        criarCard(tipo, avaliado, nomeLongo: true),
        escala: 1.8,
      );
      expect(find.text('4,8 / 5 · 12 avaliações'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('indicador tem leitura acessivel e singular correto', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    try {
      await abrir(
        tester,
        const IndicadorReputacao(reputacao: Reputacao(media: 5, total: 1)),
      );
      expect(find.text('5,0 / 5 · 1 avaliação'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Reputação: 5,0 de 5. 1 avaliação.'),
        findsOneWidget,
      );
    } finally {
      semantica.dispose();
    }
  });

  for (final tipo in [
    'home',
    'busca',
    'publicada',
    'historico',
    'recebida',
    'enviada',
  ]) {
    testWidgets('$tipo: reputacao nao interfere em abrir detalhes', (
      tester,
    ) async {
      var toques = 0;
      await abrir(tester, criarCard(tipo, avaliado, onAbrir: () => toques++));
      final alvo = tipo == 'publicada'
          ? find.text('Ver detalhes')
          : tipo == 'recebida'
          ? find.text('Passageiro teste')
          : find.text('Motorista teste');
      await tester.ensureVisible(alvo);
      await tester.tap(alvo);
      expect(toques, 1);
    });
  }

  testWidgets('recebidas preservam aceitar e recusar', (tester) async {
    var aceites = 0;
    var recusas = 0;
    await abrir(
      tester,
      criarCard(
        'recebida',
        avaliado,
        onAceitar: () => aceites++,
        onRecusar: () => recusas++,
      ),
    );
    await tester.ensureVisible(find.text('ACEITAR'));
    await tester.tap(find.text('ACEITAR'));
    await tester.tap(find.text('RECUSAR'));
    expect(aceites, 1);
    expect(recusas, 1);
  });

  testWidgets('enviadas preservam o acesso ao Pix', (tester) async {
    var pagamentos = 0;
    await abrir(
      tester,
      criarCard('enviada', avaliado, onPagar: () => pagamentos++),
    );
    await tester.ensureVisible(find.text('PAGAR COM PIX'));
    await tester.tap(find.text('PAGAR COM PIX'));
    expect(pagamentos, 1);
  });

  testWidgets('reconstruir o card mostra a reputacao atualizada', (
    tester,
  ) async {
    await abrir(tester, criarCard('home', semAvaliacoes));
    expect(find.text('Perfil ainda não avaliado'), findsOneWidget);
    await abrir(tester, criarCard('home', avaliado));
    expect(find.text('Perfil ainda não avaliado'), findsNothing);
    expect(find.text('4,8 / 5 · 12 avaliações'), findsOneWidget);
  });

  const pasta = String.fromEnvironment('REPUTACAO_EVIDENCIAS');
  if (pasta.isNotEmpty) {
    for (final tipo in ['home', 'recebida', 'enviada']) {
      testWidgets('captura visual $tipo', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await abrir(tester, criarCard(tipo, avaliado));
        final limite = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('captura-reputacao')),
        );
        await tester.runAsync(() async {
          final imagem = await limite.toImage(pixelRatio: 2);
          final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
          final arquivo = File('$pasta/reputacao-$tipo.png');
          await arquivo.parent.create(recursive: true);
          await arquivo.writeAsBytes(bytes!.buffer.asUint8List());
          imagem.dispose();
        });
      });
    }
  }
}
