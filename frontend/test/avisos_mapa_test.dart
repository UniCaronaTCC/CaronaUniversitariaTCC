import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/screens/mapa_screen.dart';
import 'package:uni_carona/mapa/widgets/barra_pesquisa_endereco.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';

import 'avisos_caronas_solicitacoes_test.dart' as avisos;
import 'mapa_precisao_test.dart' as fixtures;

const local = LocalizacaoSelecionada(
  ponto: LatLng(-21.2, -50.4),
  endereco: 'Praca de teste, 100',
);
const rua = LocalizacaoSelecionada(
  ponto: LatLng(-21.21, -50.41),
  endereco: 'Rua Brasil',
  precisao: PrecisaoLocalizacao.rua,
  pontoEspecifico: false,
  numeroBuscado: '123',
);

Future<void> executar(
  WidgetTester tester,
  Future<void> Function() corpo,
) => http.runWithClient(
  () async {
    try {
      await corpo();
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      SolicitacaoService.pararContadorSolicitacoesPendentes();
      await MensagemService.pararContadorMensagensNaoLidas();
    }
  },
  () => MockClient(
    (_) async => http.Response.bytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      200,
      headers: {'content-type': 'image/png'},
    ),
  ),
);

void conferir(WidgetTester tester, TipoAviso tipo) {
  expect(tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo, tipo);
  expect(
    tester.widget<SnackBar>(find.byType(SnackBar)).duration,
    Duration(
      seconds: tipo == TipoAviso.erro
          ? 5
          : tipo == TipoAviso.atencao
          ? 4
          : 2,
    ),
  );
  if (tipo == TipoAviso.erro || tipo == TipoAviso.sucesso) {
    avisos.conferirAviso(tester, tipo == TipoAviso.sucesso);
  }
}

Future<void> abrir(
  WidgetTester tester, {
  LocalizacaoSelecionada? inicial = local,
  bool opcional = false,
  GlobalKey<NavigatorState>? navegador,
  double escala = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navegador,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(escala)),
        child: child!,
      ),
      home: TesteMapa(
        localizacaoInicial: inicial,
        ajusteOpcional: opcional,
        enderecoService: fixtures.EnderecoMapaTeste(),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('flutter.baseflow.com/geolocator');
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var chamadasGps = 0;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
    chamadasGps = 0;
    mensageiro.setMockMethodCallHandler(canal, (_) async {
      chamadasGps++;
      return false;
    });
  });
  tearDown(() {
    mensageiro.setMockMethodCallHandler(canal, null);
  });

  testWidgets(
    'confirmacao na raiz usa sucesso verde sem alterar o ponto',
    (tester) => executar(tester, () async {
      await abrir(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.sucesso);
      expect(find.text('Ponto confirmado'), findsOneWidget);
      expect(find.text(local.endereco), findsOneWidget);
      expect(chamadasGps, 0);
    }),
  );

  testWidgets(
    'confirmacao numa rota devolve local sem popup duplicado',
    (tester) => executar(tester, () async {
      final navegador = GlobalKey<NavigatorState>();
      LocalizacaoSelecionada? retorno;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navegador,
          home: const Scaffold(body: Text('Anterior')),
        ),
      );
      unawaited(
        navegador.currentState!
            .push<LocalizacaoSelecionada>(
              MaterialPageRoute<LocalizacaoSelecionada>(
                builder: (_) => TesteMapa(
                  localizacaoInicial: local,
                  enderecoService: fixtures.EnderecoMapaTeste(),
                ),
              ),
            )
            .then((valor) => retorno = valor),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      expect(retorno, same(local));
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.byType(AvisoApp), findsNothing);
      expect(chamadasGps, 0);
    }),
  );

  testWidgets(
    'ponto aproximado estrito orienta em amarelo e mantem precisao',
    (tester) => executar(tester, () async {
      await abrir(tester, inicial: rua);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.atencao);
      expect(
        find.text('Toque no mapa para confirmar o ponto exato'),
        findsOneWidget,
      );
      expect(find.textContaining('Número 123 não confirmado.'), findsOneWidget);
      expect(find.byType(TesteMapa), findsOneWidget);
      expect(find.text('Ponto confirmado'), findsNothing);
    }),
  );

  testWidgets(
    'rua com ajuste opcional confirma sem obrigar toque',
    (tester) => executar(tester, () async {
      await abrir(tester, inicial: rua, opcional: true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.sucesso);
      expect(
        find.text('Toque no mapa para confirmar o ponto exato'),
        findsNothing,
      );
      expect(find.textContaining('Ajuste no mapa opcional.'), findsOneWidget);
      expect(chamadasGps, 0);
    }),
  );

  for (final opcional in [false, true]) {
    testWidgets(
      'regiao nao confirma como encontro opcional=$opcional',
      (tester) => executar(tester, () async {
        await abrir(
          tester,
          inicial: const LocalizacaoSelecionada(
            ponto: LatLng(-21.2, -50.4),
            endereco: 'Aracatuba',
            precisao: PrecisaoLocalizacao.regiao,
            pontoEspecifico: false,
          ),
          opcional: opcional,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR LOCAL'));
        await tester.pumpAndSettle();
        conferir(tester, TipoAviso.atencao);
        expect(
          find.text(
            opcional
                ? 'Escolha uma rua ou estabelecimento, ou marque um ponto no mapa'
                : 'Toque no mapa para confirmar o ponto exato',
          ),
          findsOneWidget,
        );
        expect(find.text('Ponto confirmado'), findsNothing);
      }),
    );
  }

  for (final situacao in [
    'desativado',
    'negado',
    'negado permanentemente',
    'lento',
  ]) {
    testWidgets(
      'GPS $situacao usa erro e permite escolha manual',
      (tester) => executar(tester, () async {
        final pendente = Completer<Map<String, dynamic>>();
        mensageiro.setMockMethodCallHandler(canal, (call) async {
          switch (call.method) {
            case 'isLocationServiceEnabled':
              return situacao != 'desativado';
            case 'checkPermission':
            case 'requestPermission':
              return situacao == 'negado'
                  ? 0
                  : situacao == 'negado permanentemente'
                  ? 1
                  : 2;
            case 'getCurrentPosition':
              return pendente.future;
            default:
              return null;
          }
        });
        await abrir(tester, inicial: null);
        if (situacao == 'lento') await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();
        conferir(tester, TipoAviso.erro);
        expect(
          find.text('Não foi possível obter sua localização'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ButtonStyleButton>(
                find
                    .ancestor(
                      of: find.text('CONFIRMAR LOCAL'),
                      matching: find.byWidgetPredicate(
                        (widget) => widget is ButtonStyleButton,
                      ),
                    )
                    .first,
              )
              .onPressed,
          isNull,
        );
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        tester
            .widget<BarraPesquisaEndereco>(find.byType(BarraPesquisaEndereco))
            .onSelecionado(local);
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR LOCAL'));
        await tester.pumpAndSettle();
        conferir(tester, TipoAviso.sucesso);
        expect(find.text(local.endereco), findsOneWidget);
        if (situacao == 'lento') {
          pendente.completeError(PlatformException(code: 'teste_encerrado'));
        }
        await tester.pumpAndSettle();
      }),
    );
  }

  for (final remover in [false, true]) {
    testWidgets(
      'falha de GPS tardia nao avisa em outra tela remover=$remover',
      (tester) => executar(tester, () async {
        final navegador = GlobalKey<NavigatorState>();
        final pendente = Completer<Map<String, dynamic>>();
        mensageiro.setMockMethodCallHandler(canal, (call) async {
          switch (call.method) {
            case 'isLocationServiceEnabled':
              return true;
            case 'checkPermission':
              return 2;
            case 'getCurrentPosition':
              return pendente.future;
            default:
              return null;
          }
        });
        await abrir(tester, inicial: null, navegador: navegador);
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
        pendente.completeError(PlatformException(code: 'gps_indisponivel'));
        await tester.pumpAndSettle();
        expect(find.text('Outra tela'), findsOneWidget);
        expect(find.byType(AvisoApp), findsNothing);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'aviso amarelo permite ajustar ponto depois sem perder coordenadas',
    (tester) => executar(tester, () async {
      await abrir(tester, inicial: rua);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.atencao);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        local.ponto,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      conferir(tester, TipoAviso.sucesso);
      expect(find.textContaining('Número 123 não confirmado.'), findsNothing);
      expect(find.text('Rua confirmada, 10'), findsOneWidget);
    }),
  );

  for (final tamanho in [const Size(320, 640), const Size(700, 360)]) {
    testWidgets(
      'aviso do mapa cabe com fonte ampliada em $tamanho',
      (tester) => executar(tester, () async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await abrir(tester, inicial: rua, escala: 1.8);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('CONFIRMAR LOCAL'));
        await tester.tap(find.text('CONFIRMAR LOCAL'));
        await tester.pumpAndSettle();
        conferir(tester, TipoAviso.atencao);
        expect(
          find.text('Toque no mapa para confirmar o ponto exato').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }),
    );
  }
}
