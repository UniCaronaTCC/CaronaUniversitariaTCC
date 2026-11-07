import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/conversa_detalhe.dart';
import 'package:uni_carona/models/conversa.dart';
import 'package:uni_carona/models/mensagem.dart';
import 'package:uni_carona/services/auth_service.dart';

Conversa conversaDeTeste(bool encerrada) => Conversa(
  id: 3,
  status: 'ACEITA',
  statusCarona: encerrada ? 'FINALIZADA' : 'ATIVA',
  idSolicitacao: 3,
  idPassageiro: 1,
  passageiro: 'Passageiro fictício',
  idMotorista: 5,
  motorista: 'Pessoa de teste de Albuquerque Santos Oliveira',
  idCarona: 3,
  destino: 'Centro Universitário, Campus Jardim das Universidades',
  dataInicio: DateTime(2026, 11, 4),
  horario: '18:30:00',
  criadoEm: DateTime(2026, 10, 30, 16, 30),
);

void main() {
  setUpAll(() async {
    final fontes = FontLoader('Inter');
    for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fontes.addFont(rootBundle.load('assets/fontes/Inter_18pt-$peso.ttf'));
    }
    await fontes.load();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  Future<void> abrir(
    WidgetTester tester, {
    required bool encerrada,
    required Future<Map<String, dynamic>> Function() carregar,
    bool compacta = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = compacta
        ? Size(320, encerrada ? 560 : 700)
        : const Size(390, 844);
    tester.view.padding = const FakeViewPadding(top: 17, bottom: 12);
    tester.view.viewInsets = FakeViewPadding(
      bottom: compacta && !encerrada ? 300 : 0,
    );
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              compacta ? (encerrada ? 1.8 : 1.5) : 1,
            ),
          ),
          child: child!,
        ),
        home: ConversaDetalheTela(
          conversa: conversaDeTeste(encerrada),
          idUsuario: 1,
          usarRealtime: false,
          carregarMensagens: carregar,
        ),
      ),
    );
  }

  for (final encerrada in [false, true]) {
    testWidgets('carregamento cabe antes da resposta encerrada=$encerrada', (
      tester,
    ) async {
      final resposta = Completer<Map<String, dynamic>>();
      await abrir(
        tester,
        encerrada: encerrada,
        carregar: () => resposta.future,
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.ensureVisible(
        find.text('Buscando o histórico desta conversa.'),
      );
      await tester.pump();
      expect(
        find.text('Buscando o histórico desta conversa.').hitTestable(),
        findsOneWidget,
      );
      resposta.complete({'sucesso': true, 'dados': <Mensagem>[]});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('conversa vazia continua acessível encerrada=$encerrada', (
      tester,
    ) async {
      await abrir(
        tester,
        encerrada: encerrada,
        carregar: () async => {'sucesso': true, 'dados': <Mensagem>[]},
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final mensagem = encerrada
          ? 'Esta conversa foi encerrada antes do envio de mensagens.'
          : 'Envie uma mensagem para combinar os detalhes da carona.';
      await tester.ensureVisible(find.text(mensagem));
      await tester.pumpAndSettle();
      expect(find.text(mensagem).hitTestable(), findsOneWidget);
      expect(find.byType(TextField), encerrada ? findsNothing : findsOneWidget);
    });

    testWidgets('erro permite rolar e tentar novamente encerrada=$encerrada', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        encerrada: encerrada,
        carregar: () async {
          chamadas++;
          return chamadas == 1
              ? {'sucesso': false, 'mensagem': 'Falha de conexão fictícia.'}
              : {
                  'sucesso': true,
                  'dados': [
                    Mensagem(
                      id: 1,
                      idRemetente: 5,
                      conteudo: 'Mensagem após tentar novamente',
                      criadoEm: DateTime(2026, 11, 4, 18),
                    ),
                  ],
                };
        },
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Tentar novamente').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      expect(find.text('Mensagem após tentar novamente'), findsOneWidget);
      final lista = find.byKey(const ValueKey('lista-mensagens'));
      expect(lista, findsOneWidget);
      expect(
        find.ancestor(of: lista, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('aviso continua centralizado quando há espaço suficiente', (
    tester,
  ) async {
    await abrir(
      tester,
      encerrada: false,
      compacta: false,
      carregar: () async => {'sucesso': true, 'dados': <Mensagem>[]},
    );
    await tester.pumpAndSettle();
    final titulo = find.text('Comece a conversa');
    expect(titulo.hitTestable(), findsOneWidget);
    expect(tester.getCenter(titulo).dx, closeTo(195, 1));
    expect(tester.takeException(), isNull);
  });
}
