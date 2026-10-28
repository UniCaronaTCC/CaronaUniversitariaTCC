import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/tela_inicial.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/widgets/card_carona_disponivel.dart';

import 'atalhos_home_test.dart' as fixtures;

Map<String, dynamic> dadosCarona(int id, {int motorista = 50}) => {
  'idCarona': id,
  'origem': 'Origem interna antiga',
  'destino': 'UniSALESIANO',
  'dataInicio': '2099-10-22',
  'horario': '19:00:00',
  'vagas': 2,
  'valor': 8,
  'status': 'ATIVA',
  'recorrente': false,
  'pontosEmbarque': [
    {
      'idPontoEmbarque': id,
      'nome': 'Praca Rui Barbosa',
      'endereco': 'Centro, Aracatuba, SP',
      'latitude': -21.2,
      'longitude': -50.4,
      'ordem': 1,
    },
  ],
  'usuario': {
    'idUsuario': motorista,
    'nome': id == 11 ? 'Pedro' : 'Henrique',
    'veiculo': {'modelo': 'Onix', 'cor': 'Branco', 'placa': '***1D23'},
  },
};

http.Response lista(List<Map<String, dynamic>> dados) => http.Response(
  jsonEncode({'sucesso': true, 'dados': dados}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = {'id': 7, 'nome': 'Pessoa'};
    AuthService.tokenUsuarioLogado = 'token-teste';
  });
  tearDown(() {
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  testWidgets('Home leva a foto do motorista da resposta HTTP ate o card', (
    tester,
  ) async {
    const foto = 'https://imagens.exemplo.com/perfil-home.jpg';
    await fixtures.executar(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('card-carona-10'));
        final avatar = tester.widget<CircleAvatar>(
          find.descendant(of: card, matching: find.byType(CircleAvatar)),
        );
        expect((avatar.foregroundImage! as NetworkImage).url, foto);
        expect(
          tester
              .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
              .carona
              .fotoMotorista,
          foto,
        );
        expect(tester.takeException(), isNull);
      },
      responder: (request) async {
        if (request.url.path == '/caronas') {
          final carona = dadosCarona(10);
          (carona['usuario'] as Map<String, dynamic>)['fotoPerfil'] = foto;
          return lista([carona]);
        }
        return lista([]);
      },
    );
  });

  testWidgets('somente disponiveis da Home usam visual novo e abrem detalhes', (
    tester,
  ) async {
    await fixtures.executar(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
        );
        await tester.pumpAndSettle();
        final cards = tester
            .widgetList<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
            .toList();
        expect(cards.where((card) => card.visualHome).length, 3);
        expect(
          cards.singleWhere((card) => card.carona.id == 99).visualHome,
          isFalse,
        );
        expect(find.byKey(const ValueKey('menu-carona-99')), findsOneWidget);
        expect(find.byKey(const ValueKey('card-carona-13')), findsNothing);
        final card = find.byKey(const ValueKey('card-carona-10'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(DetalhesCaronaTela), findsOneWidget);
        expect(
          tester
              .widget<DetalhesCaronaTela>(find.byType(DetalhesCaronaTela))
              .carona
              .id,
          10,
        );
        expect(find.text('Onix • Branco • ***1D23'), findsOneWidget);
      },
      responder: (request) async {
        if (request.url.path == '/caronas') {
          return lista([for (var id = 10; id <= 13; id++) dadosCarona(id)]);
        }
        if (request.url.path == '/caronas/minhas') {
          return lista([dadosCarona(99, motorista: 7)]);
        }
        return lista([]);
      },
    );
  });

  testWidgets('falha de listagem preserva aviso e nova tentativa', (
    tester,
  ) async {
    var falhar = true;
    await fixtures.executar(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CardCaronaDisponivel), findsNothing);
        expect(find.text('Tentar novamente'), findsOneWidget);
        falhar = false;
        await tester.ensureVisible(find.text('Tentar novamente'));
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CardCaronaDisponivel>(find.byType(CardCaronaDisponivel))
              .visualHome,
          isTrue,
        );
      },
      responder: (request) async {
        if (request.url.path == '/caronas') {
          return falhar
              ? http.Response('<html>indisponivel</html>', 503)
              : lista([dadosCarona(10)]);
        }
        return lista([]);
      },
    );
  });

  testWidgets('lista carregando nao mostra cards ficticios', (tester) async {
    final resposta = Completer<http.Response>();
    await fixtures.executar(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: TelaInicial(nomeUsuario: 'Pessoa')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CardCaronaDisponivel), findsNothing);
        resposta.complete(lista([dadosCarona(10)]));
        await tester.pumpAndSettle();
        expect(find.byType(CardCaronaDisponivel), findsOneWidget);
      },
      responder: (request) async =>
          request.url.path == '/caronas' ? resposta.future : lista([]),
    );
  });

  testWidgets('cabecalho permite ver todas em outra linha com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await fixtures.executar(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const TelaInicial(nomeUsuario: 'Pessoa'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.widgetWithText(TextButton, 'Ver todas')).dy,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.text('Caronas disponíveis')).dy,
          ),
        );
        expect(tester.takeException(), isNull);
      },
      responder: (request) async =>
          request.url.path == '/caronas' ? lista([dadosCarona(10)]) : lista([]),
    );
  });
}
