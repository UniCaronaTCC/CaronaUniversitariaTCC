import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/notificacoes.dart';
import 'package:uni_carona/models/notificacao.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/notificacao_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

Notificacao aviso(int id, {bool lida = true, String tela = 'CNH'}) =>
    Notificacao(
      id: id,
      tipo: tela,
      titulo: 'Aviso $id',
      descricao: 'Conteudo sintetico',
      criadoEm: DateTime(2026, 10, 14),
      lidaEm: lida ? DateTime(2026, 10, 14) : null,
      referencias: {'tela': tela, if (tela == 'CARONA') 'idCarona': 20},
    );

class ServicoQA extends NotificacaoService {
  int aberturas = 0;
  int consultas = 0;
  bool falharAbertura = false;
  bool paginar = false;
  String tela = 'CNH';
  bool lida = true;

  @override
  Future<Map<String, dynamic>> abrir() async {
    aberturas++;
    if (falharAbertura) {
      return {'sucesso': false, 'mensagem': 'Sem rede no primeiro clique'};
    }
    lida = true;
    return pagina();
  }

  Map<String, dynamic> pagina({bool anterior = false}) => {
    'sucesso': true,
    'dados': PaginaNotificacoes(
      itens: [aviso(anterior ? 7 : 8, lida: lida, tela: tela)],
      totalNaoLidas: lida ? 0 : 1,
      temMais: paginar && !anterior,
      proximoAntesDe: paginar && !anterior ? 8 : null,
    ),
  };

  @override
  Future<Map<String, dynamic>> listar({int? antesDe}) async {
    consultas++;
    return pagina(anterior: antesDe != null);
  }
}

class HistoricoQA extends NotificacaoService {
  final banco = List.generate(120, (i) => aviso(120 - i));
  final consultas = <int?>[];
  int aberturas = 0;
  int? falhaCursor;

  Map<String, dynamic> pagina(int? antesDe) {
    final candidatos = banco
        .where((n) => antesDe == null || n.id < antesDe)
        .toList();
    final itens = candidatos.take(50).toList();
    final temMais = candidatos.length > 50;
    return {
      'sucesso': true,
      'dados': PaginaNotificacoes(
        itens: itens,
        totalNaoLidas: banco.where((n) => n.lidaEm == null).length,
        temMais: temMais,
        proximoAntesDe: temMais ? itens.last.id : null,
      ),
    };
  }

  @override
  Future<Map<String, dynamic>> abrir() async {
    aberturas++;
    return pagina(null);
  }

  @override
  Future<Map<String, dynamic>> listar({int? antesDe}) async {
    consultas.add(antesDe);
    if (antesDe != null && antesDe == falhaCursor) {
      return {'sucesso': false, 'mensagem': 'Falha no intervalo'};
    }
    return pagina(antesDe);
  }
}

List<int> idsCarregados(WidgetTester tester) {
  final lista = tester.widget<ListView>(find.byType(ListView));
  final filhos = (lista.childrenDelegate as SliverChildListDelegate).children;
  return filhos.whereType<ListTile>().map((tile) {
    final chave = (tile.key as ValueKey<String>).value;
    return int.parse(chave.substring('notificacao_'.length));
  }).toList();
}

void main() {
  setUp(() {
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa QA'};
    AuthService.tokenUsuarioLogado = 'sintetico';
  });
  tearDown(() async {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  });

  testWidgets('QA01 realtime preserva paginas anteriores ja carregadas', (
    tester,
  ) async {
    final service = ServicoQA()..paginar = true;
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar anteriores'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notificacao_7')), findsOneWidget);
    MensagemService.versaoNotificacoes.value++;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('notificacao_7')),
      findsOneWidget,
      reason: 'Um novo aviso nao deve remover o historico aberto.',
    );
  });

  testWidgets('QA02 recuperar abertura apos falha confirma leitura', (
    tester,
  ) async {
    final service = ServicoQA()
      ..falharAbertura = true
      ..lida = false;
    var confirmacoes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacoesTela(
          service: service,
          onLeituraConfirmada: (_) => confirmacoes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem rede no primeiro clique'), findsOneWidget);
    service.falharAbertura = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Aviso 8'), findsOneWidget);
    expect(
      confirmacoes,
      1,
      reason: 'A abertura recuperada deve cumprir a leitura automatica.',
    );
  });

  testWidgets('avisos posteriores continuam nao lidos sem repetir abertura', (
    tester,
  ) async {
    final service = ServicoQA();
    var confirmacoes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NotificacoesTela(
          service: service,
          onLeituraConfirmada: (_) => confirmacoes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    service.lida = false;
    MensagemService.versaoNotificacoes.value++;
    await tester.pumpAndSettle();
    expect(service.aberturas, 1);
    expect(service.consultas, 1);
    expect(confirmacoes, 1);
    final tile = tester.widget<ListTile>(
      find.byKey(const ValueKey('notificacao_8')),
    );
    expect(tile.tileColor, isNotNull);
  });

  testWidgets('refresh manual recupera leitura pendente', (tester) async {
    final service = ServicoQA()..falharAbertura = true;
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    service.falharAbertura = false;
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(service.aberturas, 2);
    expect(find.text('Aviso 8'), findsOneWidget);
  });

  testWidgets(
    'atualizacao recupera mais de 50 novos avisos e mantem cursor antigo',
    (tester) async {
      final service = HistoricoQA();
      await tester.pumpWidget(
        MaterialApp(home: NotificacoesTela(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Carregar anteriores'),
        500,
        maxScrolls: 40,
      );
      await tester.tap(find.text('Carregar anteriores'));
      await tester.pumpAndSettle();
      expect(idsCarregados(tester), List.generate(100, (i) => 120 - i));
      service.banco.insertAll(
        0,
        List.generate(80, (i) => aviso(200 - i, lida: false)),
      );
      MensagemService.versaoNotificacoes.value++;
      await tester.pumpAndSettle();
      expect(idsCarregados(tester), List.generate(180, (i) => 200 - i));
      expect(service.consultas, [71, null, 151]);
      expect(service.aberturas, 1);
      await tester.scrollUntilVisible(
        find.text('Carregar anteriores'),
        1000,
        maxScrolls: 60,
      );
      await tester.tap(find.text('Carregar anteriores'));
      await tester.pumpAndSettle();
      expect(service.consultas.last, 21);
      expect(idsCarregados(tester), List.generate(200, (i) => 200 - i));
      expect(find.text('Carregar anteriores'), findsNothing);
    },
  );

  testWidgets('falha durante recuperacao de intervalo preserva historico', (
    tester,
  ) async {
    final service = HistoricoQA();
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    service.banco.insertAll(
      0,
      List.generate(80, (i) => aviso(200 - i, lida: false)),
    );
    service.falhaCursor = 151;
    MensagemService.versaoNotificacoes.value++;
    await tester.pumpAndSettle();
    expect(idsCarregados(tester), List.generate(50, (i) => 120 - i));
    expect(find.text('Falha no intervalo'), findsOneWidget);
    service.falhaCursor = null;
    MensagemService.versaoNotificacoes.value++;
    await tester.pumpAndSettle();
    expect(idsCarregados(tester), List.generate(130, (i) => 200 - i));
    expect(service.aberturas, 1);
  });

  for (final motorista in [false, true]) {
    testWidgets(
      motorista
          ? 'atalho preserva gerenciamento do motorista'
          : 'QA03 aviso de participante nao oferece nova solicitacao',
      (tester) async {
        AuthService.usuarioLogado = {
          'id': motorista ? 8 : 7,
          'nome': 'Pessoa QA',
        };
        final service = ServicoQA()..tela = 'CARONA';
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(home: NotificacoesTela(service: service)),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('notificacao_8')));
            await tester.pumpAndSettle();
            expect(find.byType(DetalhesCaronaTela), findsOneWidget);
            if (motorista) {
              expect(find.text('Gerenciar carona'), findsOneWidget);
            }
            expect(
              find.text('SOLICITAR VAGA'),
              findsNothing,
              reason: 'Aviso de alteracao e enviado a passageiro ja vinculado.',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            SolicitacaoService.pararContadorSolicitacoesPendentes();
            await MensagemService.pararContadorMensagensNaoLidas();
          },
          () => MockClient((req) async {
            if (req.url.path == '/caronas/20') {
              return http.Response(
                jsonEncode({
                  'sucesso': true,
                  'dados': {
                    'idCarona': 20,
                    'origem': 'Origem QA',
                    'destino': 'Destino QA',
                    'dataInicio': '2026-10-20',
                    'horario': '18:00',
                    'vagas': 2,
                    'valor': 10,
                    'recorrente': false,
                    'status': 'ATIVA',
                    'usuario': {'idUsuario': 8, 'nome': 'Motorista QA'},
                    'pontosEmbarque': [],
                  },
                }),
                200,
              );
            }
            return http.Response(
              req.url.path.contains('solicitacoes/recebidas')
                  ? '{"sucesso":true,"dados":[]}'
                  : '{"sucesso":true,"dados":{"total":0}}',
              200,
            );
          }),
        );
      },
    );
  }
}
