import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/home/ofertar_carona.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/formulario_ofertar_carona.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';

const destino = LocalizacaoSelecionada(
  ponto: LatLng(-21.1, -50.3),
  endereco: 'Campus',
  cidade: 'Aracatuba',
);
const primeiro = LocalizacaoSelecionada(
  ponto: LatLng(-21.2, -50.4),
  endereco: 'Rua A, 10',
  cidade: 'Aracatuba',
);
const segundo = LocalizacaoSelecionada(
  ponto: LatLng(-21.3, -50.5),
  endereco: 'Rua B, 20',
  cidade: 'Aracatuba',
);
const terceiro = LocalizacaoSelecionada(
  ponto: LatLng(-21.4, -50.6),
  endereco: 'Rua C, 30',
  cidade: 'Aracatuba',
);

FormularioOfertarCarona formulario(WidgetTester tester) => tester
    .widget<FormularioOfertarCarona>(find.byType(FormularioOfertarCarona));

Future<void> abrir(
  WidgetTester tester,
  Future<LocalizacaoSelecionada?> Function() selecionar,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OfertarCaronaTela(
        destinoInicial: destino,
        selecionarPontoEmbarque: selecionar,
        carregarPerfil: () async => {
          'sucesso': true,
          'dados': {
            'statusVerificacaoCnh': 'APROVADA',
            'cnhCategoria': 'B',
            'cnhValidade': '2099-12-01',
            'veiculo': {'modelo': 'Carro'},
          },
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> preencher(WidgetTester tester) async {
  formulario(tester).valorController.text = '5,00';
  formulario(tester).onSelecionarData();
  await tester.pumpAndSettle();
  tester
      .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
      .onDateChanged(DateTime.now().add(const Duration(days: 1)));
  await tester.pump();
  await tester.tap(find.text('CONFIRMAR'));
  await tester.pumpAndSettle();
  formulario(tester).onSelecionarHorario();
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
      .onDateTimeChanged(DateTime(2026, 1, 1, 18));
  await tester.tap(find.text('CONFIRMAR'));
  await tester.pumpAndSettle();
}

Future<void> adicionar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('ADICIONAR PONTO DE ENCONTRO'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ADICIONAR PONTO DE ENCONTRO'));
  await tester.pumpAndSettle();
}

Future<void> enviar(WidgetTester tester) async {
  await tester.ensureVisible(find.text('OFERTAR CARONA'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OFERTAR CARONA'));
  await tester.pumpAndSettle();
}

http.Response respostaVazia() =>
    http.Response('{"sucesso":true,"dados":[],"quantidade":0}', 200);

void testeIsolado(String nome, Future<void> Function(WidgetTester) executar) {
  testWidgets(nome, (tester) async {
    await http.runWithClient(() async {
      try {
        await executar(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        SolicitacaoService.pararContadorSolicitacoesPendentes();
        await MensagemService.pararContadorMensagensNaoLidas();
        AuthService.tokenUsuarioLogado = null;
      }
    }, () => MockClient((_) async => respostaVazia()));
  });
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.tokenUsuarioLogado = 'token-sintetico';
  });
  for (final quantidade in [1, 2]) {
    testeIsolado(
      'publica com $quantidade encontros sem informar origem ou obter GPS',
      (tester) async {
        final locais = [primeiro, segundo];
        var selecoes = 0;
        var envios = 0;
        await http.runWithClient(
          () async {
            await abrir(tester, () async => locais[selecoes++]);
            expect(find.text('Origem'), findsNothing);
            expect(find.text('Origem confirmada'), findsNothing);
            expect(find.byType(CampoDestinoCampus), findsOneWidget);
            expect(find.text('Horário do primeiro encontro'), findsOneWidget);
            for (var i = 0; i < quantidade; i++) {
              await adicionar(tester);
            }
            await preencher(tester);
            await enviar(tester);
            expect(envios, 1);
            expect(find.text('Carona criada com sucesso'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((req) async {
            if (req.method != 'POST') return respostaVazia();
            expect(req.method, 'POST');
            expect(req.url.path, '/caronas');
            envios++;
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            expect(body['origem'], primeiro.endereco);
            expect(body['origemLatitude'], -21.2);
            expect(body['origemLongitude'], -50.4);
            expect(body['origemCidade'], isNull);
            expect(body['pontosEmbarque'], hasLength(quantidade));
            expect(body['horario'], '18:00:00');
            expect(body['destino'], 'Campus');
            return http.Response('{"sucesso":true}', 201);
          }),
        );
      },
    );
  }

  testeIsolado('sem encontro nao envia a publicacao', (tester) async {
    var envios = 0;
    await http.runWithClient(
      () async {
        await abrir(tester, () async => null);
        await preencher(tester);
        await enviar(tester);
        expect(envios, 0);
        expect(
          find.text('Adicione pelo menos um ponto de encontro'),
          findsOneWidget,
        );
      },
      () => MockClient((req) async {
        if (req.method != 'POST') return respostaVazia();
        envios++;
        return http.Response('{}', 201);
      }),
    );
  });

  testeIsolado(
    'remover primeiro encontro recalcula inicio e renumera os restantes',
    (tester) async {
      var indice = 0;
      final locais = [primeiro, segundo, terceiro];
      var envios = 0;
      await http.runWithClient(
        () async {
          await abrir(tester, () async => locais[indice++]);
          await adicionar(tester);
          await adicionar(tester);
          formulario(tester).onRemoverPontoEmbarque(0);
          await tester.pumpAndSettle();
          await adicionar(tester);
          expect(formulario(tester).pontosEmbarque.map((p) => p.ordem), [1, 2]);
          await preencher(tester);
          await enviar(tester);
          expect(envios, 1);
        },
        () => MockClient((req) async {
          if (req.method != 'POST') return respostaVazia();
          envios++;
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['origem'], segundo.endereco);
          expect(body['origemLatitude'], -21.3);
          final pontos = body['pontosEmbarque'] as List;
          expect(pontos.map((p) => (p as Map)['endereco']), [
            'Rua B, 20',
            'Rua C, 30',
          ]);
          return http.Response('{"sucesso":true}', 201);
        }),
      );
    },
  );

  testeIsolado('encontro duplicado nao e adicionado', (tester) async {
    await abrir(tester, () async => primeiro);
    await adicionar(tester);
    await adicionar(tester);
    expect(formulario(tester).pontosEmbarque, hasLength(1));
    expect(
      find.text('Esse ponto de encontro já foi adicionado'),
      findsOneWidget,
    );
  });

  for (final local in <LocalizacaoSelecionada?>[
    null,
    const LocalizacaoSelecionada(
      ponto: LatLng(-21, -50),
      endereco: 'Cidade',
      pontoEspecifico: false,
    ),
    const LocalizacaoSelecionada(ponto: LatLng(-21, -50), endereco: ''),
  ]) {
    testeIsolado(
      'cancelamento ou ponto inespecifico nao cria encontro: ${local?.endereco}',
      (tester) async {
        await abrir(tester, () async => local);
        await adicionar(tester);
        expect(formulario(tester).pontosEmbarque, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testeIsolado(
    'formulario sem origem cabe em tela estreita com fonte ampliada',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(tester, () async => primeiro);
      await adicionar(tester);
      final contexto = tester.element(find.byType(FormularioOfertarCarona));
      final widget = tester.widget<OfertarCaronaTela>(
        find.byType(OfertarCaronaTela),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQuery.of(
              contexto,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: widget,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
