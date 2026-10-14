import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/notificacoes.dart';
import 'package:uni_carona/home/verificacao_cnh.dart';
import 'package:uni_carona/models/notificacao.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/notificacao_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/sino_notificacoes.dart';

Notificacao aviso(
  int id, {
  bool lida = true,
  String titulo = 'CNH conferida',
}) => Notificacao(
  id: id,
  tipo: 'CNH',
  titulo: titulo,
  descricao: 'O resultado esta disponivel para consulta.',
  criadoEm: DateTime(2026, 10, 14, 9, 30),
  lidaEm: lida ? DateTime(2026, 10, 14, 10) : null,
  referencias: const {'tela': 'CNH'},
);

class NotificacoesFake extends NotificacaoService {
  int total = 3;
  int aberturas = 0;
  int consultas = 0;
  bool falha = false;
  Completer<void>? atrasoContador;
  PaginaNotificacoes primeira = PaginaNotificacoes(
    itens: [aviso(8)],
    totalNaoLidas: 0,
  );
  PaginaNotificacoes anterior = PaginaNotificacoes(
    itens: [aviso(7)],
    totalNaoLidas: 0,
  );
  @override
  Future<Map<String, dynamic>> contar() async {
    final valor = total;
    await atrasoContador?.future;
    return {'sucesso': true, 'dados': valor};
  }

  @override
  Future<Map<String, dynamic>> abrir() async {
    aberturas++;
    if (falha) return {'sucesso': false, 'mensagem': 'Falha sintetica'};
    total = 0;
    return {'sucesso': true, 'dados': primeira};
  }

  @override
  Future<Map<String, dynamic>> listar({int? antesDe}) async {
    consultas++;
    return {'sucesso': true, 'dados': antesDe == null ? primeira : anterior};
  }
}

void main() {
  setUp(() {
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() async {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  });

  testWidgets(
    'tocar no sino le automaticamente, preserva historico e outros contadores',
    (tester) async {
      final service = NotificacoesFake();
      MensagemService.totalMensagensNaoLidas.value = 5;
      SolicitacaoService.totalSolicitacoesPendentes.value = 9;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SinoNotificacoes(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(find.text('3'), findsOneWidget);
      expect(service.aberturas, 0);
      await tester.tap(find.byTooltip('Notificações'));
      await tester.pumpAndSettle();
      expect(service.aberturas, 1);
      expect(find.text('CNH conferida'), findsOneWidget);
      expect(MensagemService.totalMensagensNaoLidas.value, 5);
      expect(SolicitacaoService.totalSolicitacoesPendentes.value, 9);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      await tester.tap(find.byTooltip('Notificações'));
      await tester.pumpAndSettle();
      expect(find.text('CNH conferida'), findsOneWidget);
      expect(service.aberturas, 2);
    },
  );

  testWidgets('abertura com erro mantem contador e permite repetir', (
    tester,
  ) async {
    final service = NotificacoesFake()..falha = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinoNotificacoes(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Falha sintetica'), findsOneWidget);
    service.falha = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(service.aberturas, 2);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('erro ao abrir nao zera contador antes da confirmacao', (
    tester,
  ) async {
    final service = NotificacoesFake()..falha = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinoNotificacoes(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('resposta antiga do contador nao ressuscita avisos ja lidos', (
    tester,
  ) async {
    final service = NotificacoesFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinoNotificacoes(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    service.atrasoContador = Completer<void>();
    MensagemService.versaoNotificacoes.value++;
    await tester.pump();
    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    service.atrasoContador!.complete();
    service.atrasoContador = null;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('aviso posterior volta ao contador e nao e lido por consulta', (
    tester,
  ) async {
    final service = NotificacoesFake()..total = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinoNotificacoes(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    service.total = 1;
    MensagemService.versaoNotificacoes.value++;
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(service.aberturas, 0);
  });

  testWidgets('contador grande usa 99+ sem mudar tamanho do sino', (
    tester,
  ) async {
    final service = NotificacoesFake()..total = 120;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SinoNotificacoes(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
    expect(tester.getSize(find.byType(SinoNotificacoes)), const Size(48, 48));
  });

  testWidgets('central vazia nao exige acao para marcar como lida', (
    tester,
  ) async {
    final service = NotificacoesFake()
      ..primeira = const PaginaNotificacoes(itens: [], totalNaoLidas: 0);
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma notificação'), findsOneWidget);
    expect(service.aberturas, 1);
  });

  testWidgets('carregar historico pagina sem novo POST nem duplicar itens', (
    tester,
  ) async {
    final service = NotificacoesFake()
      ..primeira = PaginaNotificacoes(
        itens: [aviso(8)],
        totalNaoLidas: 0,
        temMais: true,
        proximoAntesDe: 8,
      )
      ..anterior = PaginaNotificacoes(
        itens: [aviso(8), aviso(7)],
        totalNaoLidas: 0,
      );
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar anteriores'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notificacao_8')), findsOneWidget);
    expect(find.byKey(const ValueKey('notificacao_7')), findsOneWidget);
    expect(service.aberturas, 1);
    expect(service.consultas, 1);
  });

  testWidgets('atalho abre tela da CNH', (tester) async {
    AuthService.tokenUsuarioLogado = null;
    final service = NotificacoesFake();
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notificacao_8')));
    await tester.pumpAndSettle();
    expect(find.byType(VerificacaoCnhTela), findsOneWidget);
  });

  testWidgets('titulo e descricao longos cabem em tela estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = NotificacoesFake()
      ..primeira = PaginaNotificacoes(
        itens: [
          aviso(
            8,
            titulo:
                'Uma atualização importante da sua solicitação de carona para a faculdade',
          ),
        ],
        totalNaoLidas: 0,
      );
    await tester.pumpWidget(
      MaterialApp(home: NotificacoesTela(service: service)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('notificacao_8')), findsOneWidget);
  });
}
