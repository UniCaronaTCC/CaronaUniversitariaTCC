import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/home/pagamento_pix.dart';
import 'package:uni_carona/models/pagamento_pix.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/pagamento_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

import 'avisos_caronas_solicitacoes_test.dart' as fixtures;

PagamentoPix pagamento({String status = 'PENDING'}) => PagamentoPix(
  id: 30,
  idSolicitacao: 10,
  metodo: 'PIX',
  valorCentavos: 1250,
  statusCriacao: 'CONFIRMADA',
  status: status,
  pixCopiaECola: 'pix-sintetico-teste',
  qrCodeBase64: null,
  expiraEm: null,
  modoTeste: true,
);

class PagamentoControlado extends PagamentoService {
  Future<Map<String, dynamic>> Function()? consultar;
  Future<Map<String, dynamic>> Function()? simular;
  Future<Map<String, dynamic>> Function()? preparar;
  int consultas = 0;
  int simulacoes = 0;
  int preparacoes = 0;

  PagamentoControlado()
    : super(
        cliente: MockClient(
          (_) async => throw StateError('Requisicao HTTP inesperada no teste'),
        ),
      );

  @override
  Future<Map<String, dynamic>> obterPagamento(int id) async {
    expect(id, 30);
    consultas++;
    return consultar?.call() ?? {'sucesso': true, 'dados': pagamento()};
  }

  @override
  Future<Map<String, dynamic>> simularPagamento(int id) async {
    expect(id, 30);
    simulacoes++;
    return simular?.call() ?? {'sucesso': true};
  }

  @override
  Future<Map<String, dynamic>> criarOuObterPix(int id) async {
    expect(id, 10);
    preparacoes++;
    return preparar?.call() ??
        {'sucesso': false, 'mensagem': 'Falha ao preparar Pix'};
  }
}

Future<void> abrir(
  WidgetTester tester,
  PagamentoControlado service, {
  GlobalKey<NavigatorState>? navegador,
  bool automatico = false,
  String status = 'PENDING',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navegador,
      home: PagamentoPixTela(
        pagamento: pagamento(status: status),
        pagamentoService: service,
        atualizarAutomaticamente: automatico,
        intervaloAtualizacao: const Duration(milliseconds: 100),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> simular(WidgetTester tester) async {
  await tester.ensureVisible(find.text('SIMULAR PAGAMENTO'));
  await tester.tap(find.text('SIMULAR PAGAMENTO'));
}

void conferir(WidgetTester tester, TipoAviso tipo, Duration duracao) {
  expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, tipo);
  expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, duracao);
  if (tipo == TipoAviso.sucesso || tipo == TipoAviso.erro) {
    fixtures.conferirAviso(tester, tipo == TipoAviso.sucesso);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() async {
    mensageiro.setMockMethodCallHandler(SystemChannels.platform, null);
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  });

  testWidgets(
    'copiar Pix confirma em verde por 1,5 segundo e copia o valor exato',
    (tester) async {
      String? copiado;
      mensageiro.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          copiado = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      final service = PagamentoControlado();
      await abrir(tester, service);
      await tester.ensureVisible(find.text('COPIAR CÓDIGO PIX'));
      await tester.tap(find.text('COPIAR CÓDIGO PIX'));
      await tester.pumpAndSettle();
      expect(copiado, 'pix-sintetico-teste');
      expect(find.text('Código Pix copiado'), findsOneWidget);
      conferir(tester, TipoAviso.sucesso, const Duration(milliseconds: 1500));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(AvisoApp), findsNothing);
      expect(service.consultas, 0);
      expect(service.simulacoes, 0);
    },
  );

  testWidgets('confirmacao automatica aparece uma vez e para as consultas', (
    tester,
  ) async {
    final service = PagamentoControlado()
      ..consultar = () async => {
        'sucesso': true,
        'dados': pagamento(status: 'PAID'),
      };
    await abrir(tester, service, automatico: true);
    conferir(tester, TipoAviso.sucesso, const Duration(seconds: 2));
    expect(find.text('Pagamento confirmado'), findsNWidgets(2));
    expect(find.text('COPIAR CÓDIGO PIX'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(service.consultas, 1);
    expect(find.byType(AvisoApp), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pagamento ja confirmado nao anuncia nem consulta novamente', (
    tester,
  ) async {
    final service = PagamentoControlado();
    await abrir(tester, service, automatico: true, status: 'PAID');
    expect(find.byType(AvisoApp), findsNothing);
    expect(find.text('Pagamento confirmado'), findsOneWidget);
    expect(service.consultas, 0);
  });

  testWidgets('consulta pendente mantem o status sem gerar aviso', (
    tester,
  ) async {
    final service = PagamentoControlado();
    await abrir(tester, service);
    await tester.tap(find.byTooltip('Atualizar pagamento'));
    await tester.pumpAndSettle();
    expect(find.byType(AvisoApp), findsNothing);
    expect(find.text('Aguardando pagamento'), findsOneWidget);
    expect(service.consultas, 1);
  });

  testWidgets('simulacao pendente informa sem anunciar pagamento confirmado', (
    tester,
  ) async {
    final service = PagamentoControlado();
    await abrir(tester, service);
    await simular(tester);
    await tester.pumpAndSettle();
    conferir(tester, TipoAviso.informacao, const Duration(seconds: 4));
    expect(
      find.text('Pagamento simulado. Aguardando confirmação'),
      findsOneWidget,
    );
    expect(find.textContaining('webhook'), findsNothing);
    expect(find.text('Pagamento confirmado'), findsNothing);
    expect(service.simulacoes, 1);
    expect(service.consultas, 1);
  });

  testWidgets(
    'confirmacao apos simulacao respeita a fila informacao e sucesso',
    (tester) async {
      final service = PagamentoControlado()
        ..consultar = () async => {
          'sucesso': true,
          'dados': pagamento(status: 'PAID'),
        };
      await abrir(tester, service);
      await simular(tester);
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.informacao, const Duration(seconds: 4));
      expect(find.text('SIMULAR PAGAMENTO'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.sucesso, const Duration(seconds: 2));
      expect(service.simulacoes, 1);
      expect(service.consultas, 1);
    },
  );

  testWidgets('falha ao simular permanece na tela e libera nova tentativa', (
    tester,
  ) async {
    var falhar = true;
    final service = PagamentoControlado()
      ..simular = () async => {
        'sucesso': !falhar,
        'mensagem': 'Falha simulada',
      };
    await abrir(tester, service);
    await simular(tester);
    await tester.pumpAndSettle();
    expect(find.text('Falha simulada'), findsOneWidget);
    expect(find.byType(AvisoApp), findsNothing);
    expect(service.consultas, 0);
    falhar = false;
    await simular(tester);
    await tester.pumpAndSettle();
    expect(service.simulacoes, 2);
    expect(service.consultas, 1);
    expect(find.text('Falha simulada'), findsNothing);
    conferir(tester, TipoAviso.informacao, const Duration(seconds: 4));
  });

  testWidgets(
    'falhas de consulta automatica ficam na tela sem empilhar avisos',
    (tester) async {
      final service = PagamentoControlado()
        ..consultar = () async => {
          'sucesso': false,
          'mensagem': 'Atualizacao indisponivel',
        };
      await abrir(tester, service, automatico: true);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Atualizacao indisponivel'), findsOneWidget);
      expect(find.byType(AvisoApp), findsNothing);
      expect(service.consultas, greaterThan(1));
      expect(find.text('COPIAR CÓDIGO PIX'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final remover in [false, true]) {
    for (final operacao in ['copiar', 'consultar', 'simular']) {
      testWidgets(
        'resposta tardia $operacao nao avisa fora da tela remover=$remover',
        (tester) async {
          final pendente = Completer<void>();
          final navegador = GlobalKey<NavigatorState>();
          final service = PagamentoControlado();
          if (operacao == 'copiar') {
            mensageiro.setMockMethodCallHandler(SystemChannels.platform, (
              call,
            ) async {
              if (call.method == 'Clipboard.setData') await pendente.future;
              return null;
            });
          } else if (operacao == 'consultar') {
            service.consultar = () async {
              await pendente.future;
              return {'sucesso': true, 'dados': pagamento(status: 'PAID')};
            };
          } else {
            service.simular = () async {
              await pendente.future;
              return {'sucesso': true};
            };
          }
          await abrir(tester, service, navegador: navegador);
          if (operacao == 'copiar') {
            await tester.ensureVisible(find.text('COPIAR CÓDIGO PIX'));
            await tester.tap(find.text('COPIAR CÓDIGO PIX'));
          } else if (operacao == 'consultar') {
            await tester.tap(find.byTooltip('Atualizar pagamento'));
          } else {
            await simular(tester);
          }
          await tester.pump();
          if (remover) {
            await tester.pumpWidget(
              const MaterialApp(home: Scaffold(body: Text('Outra tela'))),
            );
          } else {
            unawaited(
              navegador.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Outra tela')),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          pendente.complete();
          await tester.pumpAndSettle();
          expect(find.text('Outra tela'), findsOneWidget);
          expect(find.byType(AvisoApp), findsNothing);
          if (!remover && operacao == 'consultar') {
            navegador.currentState!.pop();
            await tester.pumpAndSettle();
            expect(find.text('Pagamento confirmado'), findsOneWidget);
            expect(find.text('COPIAR CÓDIGO PIX'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('simulacao em andamento desabilita botao e nao duplica POST', (
    tester,
  ) async {
    final pendente = Completer<Map<String, dynamic>>();
    final service = PagamentoControlado()..simular = () => pendente.future;
    await abrir(tester, service);
    await simular(tester);
    await tester.pump();
    await tester.tap(find.text('SIMULAR PAGAMENTO'));
    await tester.pump();
    expect(service.simulacoes, 1);
    pendente.complete({'sucesso': true});
    await tester.pumpAndSettle();
    expect(service.consultas, 1);
  });

  for (final tardia in [false, true]) {
    testWidgets(
      'preparacao do Pix falha em vermelho sem navegar tardia=$tardia',
      (tester) async {
        final navegador = GlobalKey<NavigatorState>();
        final pendente = Completer<Map<String, dynamic>>();
        final service = PagamentoControlado()
          ..preparar = () => tardia
              ? pendente.future
              : Future.value({
                  'sucesso': false,
                  'mensagem': 'Falha ao preparar Pix',
                });
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navegador,
            home: MinhasCaronasTela(
              pagamentoService: service,
              carregarRecebidas: () async => {'sucesso': true, 'dados': []},
              carregarEnviadas: () async => {'sucesso': true, 'dados': []},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic estado = tester.state(find.byType(MinhasCaronasTela));
        final Future<void> operacao = estado.pagarComPix(
          SolicitacaoEnviada(
            id: 10,
            status: 'ACEITA',
            localEmbarque: 'Praca',
            motorista: 'Teste',
            idCarona: 1,
            destino: 'Campus',
            dataInicio: DateTime(2026, 11, 2),
            horario: '19:00',
            valor: 12.5,
          ),
        );
        await tester.pump();
        if (tardia) {
          unawaited(
            navegador.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Outra tela')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          pendente.complete({
            'sucesso': false,
            'mensagem': 'Falha ao preparar Pix',
          });
        }
        await tester.pumpAndSettle();
        await operacao;
        if (tardia) {
          expect(find.byType(AvisoApp), findsNothing);
          expect(find.text('Outra tela'), findsOneWidget);
        } else {
          conferir(tester, TipoAviso.erro, const Duration(seconds: 5));
          expect(find.text('Falha ao preparar Pix'), findsOneWidget);
        }
        expect(find.byType(PagamentoPixTela), findsNothing);
        expect(service.preparacoes, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
