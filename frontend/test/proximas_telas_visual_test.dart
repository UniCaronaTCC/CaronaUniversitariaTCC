import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/conversas.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/home/recorrencias.dart';
import 'package:uni_carona/home/historico_caronas.dart';
import 'package:uni_carona/home/avaliacoes_recebidas.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';
import 'package:uni_carona/models/recorrencia_carona.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

const saida = String.fromEnvironment('PREVIA_PROXIMAS_TELAS');
var textosLongos = false;
final agora = DateTime(2026, 10, 30, 16, 30);
Mensagem mensagem(int id, int remetente, String texto) => Mensagem(
  id: id,
  idRemetente: remetente,
  conteudo: texto,
  criadoEm: agora.subtract(Duration(minutes: 5 - id)),
);
Conversa conversa(
  int id,
  String nome,
  String ultima, {
  int naoLidas = 0,
  bool encerrada = false,
}) => Conversa(
  id: id,
  status: 'ACEITA',
  statusCarona: encerrada ? 'FINALIZADA' : 'ATIVA',
  encerradaEm: encerrada ? agora.subtract(const Duration(days: 2)) : null,
  idSolicitacao: id,
  idPassageiro: 1,
  passageiro: 'Marina Santos',
  idMotorista: id + 2,
  motorista: textosLongos ? '$nome de Albuquerque Santos Oliveira' : nome,
  idCarona: id,
  destino: textosLongos
      ? 'Centro Universitário, Campus Jardim das Universidades'
      : 'UniSalesiano, Araçatuba',
  dataInicio: DateTime(2026, 11, 4),
  horario: '18:30:00',
  criadoEm: agora,
  ultimaMensagem: mensagem(id, id + 2, ultima),
  mensagensNaoLidas: naoLidas,
);
Carona carona(int id, {bool finalizada = false}) => Carona(
  id: id,
  origem: 'Praça Central, Centro',
  destino: textosLongos
      ? 'Centro Universitário, Campus Jardim das Universidades'
      : 'UniSalesiano, Araçatuba',
  dataInicio: finalizada ? DateTime(2026, 10, 28) : DateTime(2026, 11, 4),
  horario: '18:30:00',
  vagas: 3,
  valor: 8,
  recorrente: !finalizada,
  diasSemana: const ['SEG', 'QUA', 'SEX'],
  motorista: 'Marina Santos',
  status: finalizada ? 'FINALIZADA' : 'ATIVA',
);
Widget tela(String nome) => switch (nome) {
  'conversas' => ConversasTela(
    idUsuario: 1,
    agora: () => agora,
    carregarConversas: () async => {
      'sucesso': true,
      'dados': [
        conversa(1, 'Lucas Almeida', 'Já estou na praça!', naoLidas: 2),
        conversa(2, 'Ana Souza', 'Combinado, até mais!'),
        conversa(3, 'Pedro Lima', 'Obrigado pela carona!', encerrada: true),
      ],
    },
  ),
  'chat' => ConversaDetalheTela(
    conversa: conversa(1, 'Lucas Almeida', 'Já estou na praça!'),
    idUsuario: 1,
    usarRealtime: false,
    carregarMensagens: () async => {
      'sucesso': true,
      'dados': [
        mensagem(1, 3, 'Oi! A saída é às 18h30, certo?'),
        mensagem(2, 1, 'Isso! Te encontro na Praça Central.'),
        mensagem(3, 3, 'Perfeito, já estou na praça!'),
        mensagem(4, 1, 'Combinado! Até já.'),
      ],
    },
  ),
  'recorrencias' => RecorrenciasTela(
    carregar: () async => [
      RecorrenciaCarona(id: 1, ativa: true, configuracao: carona(1)),
      RecorrenciaCarona(id: 2, ativa: false, configuracao: carona(2)),
    ],
  ),
  'historico' => HistoricoCaronasTela(
    carregarOfertas: () async => {
      'sucesso': true,
      'dados': [carona(1), carona(2, finalizada: true)],
    },
    carregarPedidos: () async => {
      'sucesso': true,
      'dados': <SolicitacaoEnviada>[],
    },
  ),
  'avaliacoes' => AvaliacoesRecebidasTela(
    idUsuario: 1,
    nomeUsuario: 'Marina Santos',
    carregarAvaliacoes: (_, _) async => {
      'sucesso': true,
      'dados': {
        'media': 4.8,
        'total': 15,
        'pagina': 1,
        'totalPaginas': 1,
        'avaliacoes': [
          {
            'id': 1,
            'nota': 5,
            'comentario': 'Pontual e muito atenciosa. Recomendo!',
            'criadoEm': '2026-10-28T15:00:00Z',
            'avaliador': {'id': 2, 'nome': 'Lucas Almeida'},
          },
          {
            'id': 2,
            'nota': 5,
            'comentario': 'Viagem tranquila e ótima companhia.',
            'criadoEm': '2026-10-27T15:00:00Z',
            'avaliador': {'id': 3, 'nome': 'Ana Souza'},
          },
          {
            'id': 3,
            'nota': 4,
            'comentario': 'Tudo certo com a carona!',
            'criadoEm': '2026-10-26T15:00:00Z',
            'avaliador': {'id': 4, 'nome': 'Pedro Lima'},
          },
        ],
      },
    },
  ),
  _ => throw ArgumentError(nome),
};
// Confere a tela inteira e seus estados em celulares menores, sem acessar o servidor.
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  final cenarios = [
    (
      nome: '390px',
      tamanho: const Size(390, 844),
      escala: 1.0,
      teclado: 0.0,
      encerrada: false,
    ),
    (
      nome: '320px fonte 180%',
      tamanho: const Size(320, 700),
      escala: 1.8,
      teclado: 0.0,
      encerrada: false,
    ),
    (
      nome: 'chat com teclado',
      tamanho: const Size(320, 700),
      escala: 1.5,
      teclado: 300.0,
      encerrada: false,
    ),
    (
      nome: 'chat encerrado',
      tamanho: const Size(320, 560),
      escala: 1.8,
      teclado: 0.0,
      encerrada: true,
    ),
  ];
  for (final cenario in cenarios) {
    for (final nome in [
      'conversas',
      'chat',
      'recorrencias',
      'historico',
      'avaliacoes',
    ]) {
      if ((cenario.teclado > 0 || cenario.encerrada) && nome != 'chat') {
        continue;
      }
      testWidgets('$nome: ${cenario.nome}', (tester) async {
        textosLongos = cenario.escala > 1;
        tester.view.physicalSize = cenario.tamanho;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: cenario.teclado);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await (FontLoader('Inter')
              ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Regular.ttf'))
              ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Medium.ttf'))
              ..addFont(
                rootBundle.load('assets/fontes/Inter_18pt-SemiBold.ttf'),
              )
              ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Bold.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
              rootBundle.load(
                'packages/cupertino_icons/assets/CupertinoIcons.ttf',
              ),
            ))
            .load();
        final erros = <String>[];
        final anterior = FlutterError.onError;
        FlutterError.onError = (detalhes) {
          erros.add(detalhes.toString());
          anterior?.call(detalhes);
        };
        addTearDown(() => FlutterError.onError = anterior);
        final chave = GlobalKey();
        final pagina = cenario.encerrada
            ? ConversaDetalheTela(
                conversa: conversa(
                  3,
                  'Lucas Almeida',
                  'Obrigado!',
                  encerrada: true,
                ),
                idUsuario: 1,
                usarRealtime: false,
                carregarMensagens: () async => {
                  'sucesso': true,
                  'dados': [mensagem(1, 3, 'Obrigado pela carona!')],
                },
              )
            : tela(nome);
        await tester.pumpWidget(
          RepaintBoundary(
            key: chave,
            child: MaterialApp(
              key: ValueKey('$nome-${cenario.nome}'),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(cenario.escala)),
                child: child!,
              ),
              home: pagina,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: erros.join('\n'));
        if (saida.isNotEmpty && cenario.escala == 1) {
          await tester.runAsync(() async {
            final boundary =
                chave.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final imagem = await boundary.toImage(pixelRatio: 2);
            final bytes = await imagem.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(saida).create(recursive: true);
            await File(
              '$saida/$nome-depois-real.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            imagem.dispose();
          });
        }
        final rolagem = find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        );
        if (nome != 'chat' && rolagem.evaluate().isNotEmpty) {
          for (var i = 0; i < 7; i++) {
            await tester.drag(rolagem.first, const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: erros.join('\n'));
          }
        }
        if (nome == 'conversas') {
          await tester.ensureVisible(find.text('Encerradas'));
          await tester.tap(find.text('Encerradas'));
          await tester.pumpAndSettle();
          expect(find.text('Encerrada'), findsOneWidget);
        }
        if (nome == 'historico') {
          await tester.ensureVisible(find.text('Como passageiro'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Como passageiro'));
          await tester.pumpAndSettle();
          expect(find.text('Viagens confirmadas'), findsOneWidget);
        }
        if (cenario.teclado > 0) {
          await tester.enterText(
            find.byType(TextField),
            'Estou chegando, te encontro na praça. ' * 20,
          );
          await tester.pumpAndSettle();
          expect(find.byTooltip('Enviar mensagem'), findsOneWidget);
        }
        if (cenario.encerrada) {
          expect(find.byType(TextField), findsNothing);
          expect(find.text('Conversa encerrada'), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: erros.join('\n'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        SolicitacaoService.pararContadorSolicitacoesPendentes();
        await MensagemService.pararContadorMensagensNaoLidas();
      });
    }
  }
}
