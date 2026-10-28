import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/buscar_carona.dart';
import 'package:uni_carona/home/ofertar_carona.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/card_destino_home.dart';
import 'package:uni_carona/widgets/sino_notificacoes.dart';

const local = LocalizacaoSelecionada(
  ponto: LatLng(-21.235275, -50.4060626),
  nome: 'Faculdade',
  endereco: 'Rodovia, 3821',
);
const novo = LocalizacaoSelecionada(
  ponto: LatLng(-21.2, -50.4),
  nome: 'Outro local',
  endereco: 'Rua A, 10',
);

http.Client cliente() => MockClient(
  (request) async =>
      http.Response(jsonEncode({'sucesso': true, 'dados': []}), 200),
);

Future<void> executar(Future<void> Function() acao) =>
    http.runWithClient(() async {
      try {
        await acao();
      } finally {
        SolicitacaoService.pararContadorSolicitacoesPendentes();
        await MensagemService.pararContadorMensagensNaoLidas();
      }
    }, cliente);

class DestinoLento extends DestinoPreferidoService {
  final pendente = Completer<LocalizacaoSelecionada?>();
  @override
  Future<LocalizacaoSelecionada?> carregar(int idUsuario) => pendente.future;
}

class DestinoFalha extends DestinoPreferidoService {
  @override
  Future<void> salvar(int idUsuario, LocalizacaoSelecionada destino) async {
    throw StateError('Falha sintetica de armazenamento');
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  testWidgets('Home restaura destino e preenche tela de busca', (tester) async {
    await const DestinoPreferidoService().salvar(7, local);
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).destino,
        local.descricaoCompleta,
      );
      expect(find.text('Faculdade'), findsOneWidget);
      expect(find.text('Rodovia, 3821'), findsOneWidget);
      await tester.tap(find.text('Buscar carona'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
            .destinoInicial
            ?.toJson(),
        local.toJson(),
      );
    });
  });

  testWidgets('escolha salva novo destino e outra Home o restaura', (
    tester,
  ) async {
    await const DestinoPreferidoService().salvar(7, local);
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CardDestinoHome));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(SelecionarDestinoTela)),
      ).pop(novo);
      await tester.pumpAndSettle();
      expect(
        (await const DestinoPreferidoService().carregar(7))?.toJson(),
        novo.toJson(),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).destino,
        novo.descricaoCompleta,
      );
    });
  });

  testWidgets('cancelar escolha preserva preferencia anterior', (tester) async {
    await const DestinoPreferidoService().salvar(7, local);
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CardDestinoHome));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).destino,
        local.descricaoCompleta,
      );
      expect(
        (await const DestinoPreferidoService().carregar(7))?.toJson(),
        local.toJson(),
      );
    });
  });

  testWidgets('outra conta nao herda destino ao reconstruir Home', (
    tester,
  ) async {
    await const DestinoPreferidoService().salvar(7, local);
    AuthService.usuarioLogado = {'id': 8, 'nome': 'Outra pessoa'};
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Outra pessoa')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).destino,
        'Escolha seu destino',
      );
    });
  });

  testWidgets('buscar aguarda restauracao para nao perder filtro salvo', (
    tester,
  ) async {
    final service = DestinoLento();
    await executar(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TelaInicial(
            nomeUsuario: 'Pessoa',
            destinoPreferidoService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar carona'));
      await tester.pump();
      expect(find.byType(BuscarCaronaTela), findsNothing);
      service.pendente.complete(local);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BuscarCaronaTela>(find.byType(BuscarCaronaTela))
            .destinoInicial
            ?.toJson(),
        local.toJson(),
      );
    });
  });

  testWidgets('falha ao salvar avisa e mantem destino anterior', (
    tester,
  ) async {
    await const DestinoPreferidoService().salvar(7, local);
    await executar(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TelaInicial(
            nomeUsuario: 'Pessoa',
            destinoPreferidoService: DestinoFalha(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CardDestinoHome));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byType(SelecionarDestinoTela)),
      ).pop(novo);
      await tester.pumpAndSettle();
      expect(
        tester.widget<CardDestinoHome>(find.byType(CardDestinoHome)).destino,
        local.descricaoCompleta,
      );
      expect(find.textContaining('salvar seu destino'), findsOneWidget);
      expect(
        (await const DestinoPreferidoService().carregar(7))?.toJson(),
        local.toJson(),
      );
    });
  });

  testWidgets('cabecalho apresenta marca, saudacao e sino sem mudar acoes', (
    tester,
  ) async {
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      expect(find.text('BuscaEu'), findsOneWidget);
      expect(find.text('Olá, Pessoa'), findsOneWidget);
      expect(find.byTooltip('Notificações'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('BuscaEu')).dy,
        lessThan(tester.getTopLeft(find.text('Olá, Pessoa')).dy),
      );
      expect(
        tester.getTopRight(find.text('BuscaEu')).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(SinoNotificacoes)).dx),
      );
      expect(find.text('Buscar carona'), findsOneWidget);
      expect(find.text('Oferecer carona'), findsOneWidget);
      expect(find.text('Seu destino'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('saudacao vazia tem alternativa legivel', (tester) async {
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: '  ')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Olá, usuário'), findsOneWidget);
    });
  });

  for (final escala in [1.5, 2.0]) {
    testWidgets(
      'Home estreita preserva rolagem com nome longo e fonte $escala',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await const DestinoPreferidoService().salvar(7, local);
        await executar(() async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(escala)),
                child: child!,
              ),
              home: const TelaInicial(
                nomeUsuario: 'João Henrique de Souza Martins Ferreira',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('BuscaEu'), findsOneWidget);
          expect(
            find.text('Olá, João Henrique de Souza Martins Ferreira'),
            findsOneWidget,
          );
          expect(find.text('Faculdade'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Buscar carona'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Buscar carona'));
          await tester.pumpAndSettle();
          expect(find.byType(BuscarCaronaTela), findsOneWidget);
        });
      },
    );
  }

  testWidgets('novo botao de oferecer abre formulario com destino salvo', (
    tester,
  ) async {
    await const DestinoPreferidoService().salvar(7, local);
    await executar(() async {
      await tester.pumpWidget(
        const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Oferecer carona'));
      await tester.tap(find.text('Oferecer carona'));
      await tester.pumpAndSettle();
      expect(find.byType(OfertarCaronaTela), findsOneWidget);
      expect(
        tester
            .widget<OfertarCaronaTela>(find.byType(OfertarCaronaTela))
            .destinoInicial
            ?.toJson(),
        local.toJson(),
      );
    });
  });
}
