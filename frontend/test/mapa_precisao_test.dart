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
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';
import 'package:uni_carona/services/campus_destino_service.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';

class CatalogoMapaTeste extends CampusDestinoService {
  Completer<List<CampusDestino>>? pendente;
  @override
  Future<CidadeCampus?> identificarCidade() async =>
      const CidadeCampus('Araçatuba', 'SP');
  @override
  Future<List<CampusDestino>> listar(
    CidadeCampus cidade, {
    Duration prazo = const Duration(seconds: 20),
  }) => pendente?.future ?? Future.value([]);
}

class EnderecoMapaTeste extends EnderecoService {
  List<LocalizacaoSelecionada> encontrados = [];
  @override
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado, {
    double? latitudeReferencia,
    double? longitudeReferencia,
    String? cidadeReferencia,
    String? estadoReferencia,
  }) async => encontrados;
  int consultas = 0;
  Future<LocalizacaoSelecionada?>? pendente;
  bool falhar = false;
  @override
  Future<LocalizacaoSelecionada?> buscarLocalizacaoPorCoordenadas(
    double latitude,
    double longitude,
  ) {
    consultas++;
    if (falhar) {
      return Future.error(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    }
    return pendente ??
        Future.value(
          LocalizacaoSelecionada(
            ponto: LatLng(latitude, longitude),
            endereco: 'Rua confirmada, 10',
            rua: 'Rua confirmada',
            numero: '10',
            cidade: 'Araçatuba',
            estado: 'SP',
          ),
        );
  }
}

void main() {
  const inicial = LocalizacaoSelecionada(
    ponto: LatLng(-21.2, -50.4),
    endereco: 'Rua Brasil',
    nome: 'Rua Brasil',
    rua: 'Rua Brasil',
    precisao: PrecisaoLocalizacao.rua,
    pontoEspecifico: false,
    numeroBuscado: '123',
  );
  const novo = LatLng(-21.21, -50.41);
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('flutter.baseflow.com/geolocator');
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late EnderecoMapaTeste enderecos;
  LocalizacaoSelecionada? resultado;
  var chamadasGps = 0;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
    enderecos = EnderecoMapaTeste();
    resultado = null;
    chamadasGps = 0;
    mensageiro.setMockMethodCallHandler(canal, (_) async {
      chamadasGps++;
      return null;
    });
  });
  tearDown(() async {
    mensageiro.setMockMethodCallHandler(canal, null);
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
  });
  Future<void> comTiles(
    WidgetTester tester,
    Future<void> Function() corpo,
  ) => http.runWithClient(
    () async {
      try {
        await corpo();
      } finally {
        await tester.pumpWidget(const SizedBox());
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
  Future<void> abrir(
    WidgetTester tester, {
    LocalizacaoSelecionada local = inicial,
    double escala = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await Navigator.of(context)
                    .push<LocalizacaoSelecionada>(
                      MaterialPageRoute(
                        builder: (_) => TesteMapa(
                          localizacaoInicial: local,
                          enderecoService: enderecos,
                        ),
                      ),
                    );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> marcar(WidgetTester tester) async {
    tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      novo,
    );
    await tester.pumpAndSettle();
  }

  Future<TextEditingController> abrirDestino(
    WidgetTester tester, {
    CatalogoMapaTeste? catalogo,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    enderecos.encontrados = [inicial];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CampoDestinoCampus(
              controller: controller,
              mostrarAoAbrir: true,
              campusService: catalogo ?? CatalogoMapaTeste(),
              enderecoService: enderecos,
              onSelecionado: (local) => resultado = local,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Rua Brasil, 123');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Rua Brasil').first);
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'destino aproximado abre mapa e cancelar preserva texto sem selecionar',
    (tester) => comTiles(tester, () async {
      final controller = await abrirDestino(tester);
      expect(find.byType(TesteMapa), findsOneWidget);
      expect(resultado, isNull);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(resultado, isNull);
      expect(controller.text, 'Rua Brasil, 123');
      expect(find.byType(CampoDestinoCampus), findsOneWidget);
      expect(tester.takeException(), isNull);
    }),
  );
  testWidgets(
    'destino so seleciona depois de marcar e confirmar no mapa',
    (tester) => comTiles(tester, () async {
      final controller = await abrirDestino(tester);
      expect(resultado, isNull);
      await marcar(tester);
      await tester.tap(find.text('CONFIRMAR DESTINO'));
      await tester.pumpAndSettle();
      expect(resultado!.ponto, novo);
      expect(resultado!.exigeAjusteNoMapa, false);
      expect(controller.text, 'Rua confirmada, 10');
      expect(find.byType(TesteMapa), findsNothing);
      expect(tester.takeException(), isNull);
    }),
  );
  testWidgets(
    'catalogo atrasado nao invalida confirmacao de destino no mapa',
    (tester) => comTiles(tester, () async {
      final catalogo = CatalogoMapaTeste()
        ..pendente = Completer<List<CampusDestino>>();
      await abrirDestino(tester, catalogo: catalogo);
      catalogo.pendente!.complete([]);
      await tester.pumpAndSettle();
      await marcar(tester);
      await tester.tap(find.text('CONFIRMAR DESTINO'));
      await tester.pumpAndSettle();
      expect(resultado!.ponto, novo);
      expect(tester.takeException(), isNull);
    }),
  );
  testWidgets(
    'texto longo e aviso aproximado cabem em tela estreita com fonte grande',
    (tester) => comTiles(tester, () async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await abrir(
        tester,
        escala: 1.8,
        local: LocalizacaoSelecionada(
          ponto: inicial.ponto,
          endereco: List.filled(
            6,
            'Avenida de nome muito comprido, Bairro distante',
          ).join(', '),
          precisao: PrecisaoLocalizacao.rua,
          pontoEspecifico: false,
        ),
      );
      final contexto = tester.element(find.byType(TesteMapa));
      // Verifica o painel rolavel sem alterar as regras de selecao.
      expect(MediaQuery.sizeOf(contexto).width, 320);
      await tester.ensureVisible(find.text('CONFIRMAR LOCAL'));
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    'aproximado inicia no resultado sem GPS e nao confirma centro da rua',
    (tester) => comTiles(tester, () async {
      await abrir(tester);
      expect(chamadasGps, 0);
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .options
            .initialCenter,
        inicial.ponto,
      );
      expect(find.text(inicial.avisoPrecisao!), findsOneWidget);
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      expect(resultado, isNull);
      expect(find.byType(TesteMapa), findsOneWidget);
      expect(
        find.text('Toque no mapa para confirmar o ponto exato'),
        findsOneWidget,
      );
    }),
  );
  testWidgets(
    'ponto marcado e confirmado retorna coordenadas novas e remove aproximacao',
    (tester) => comTiles(tester, () async {
      await abrir(tester);
      await marcar(tester);
      expect(find.text(inicial.avisoPrecisao!), findsNothing);
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      expect(resultado!.ponto, novo);
      expect(resultado!.exigeAjusteNoMapa, false);
      expect(resultado!.numeroBuscado, isNull);
      expect(resultado!.numero, '10');
      expect(resultado!.endereco, 'Rua confirmada, 10');
      expect(tester.takeException(), isNull);
    }),
  );
  testWidgets(
    'cancelar nao retorna destino',
    (tester) => comTiles(tester, () async {
      await abrir(tester);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(resultado, isNull);
      expect(find.text('Abrir'), findsOneWidget);
    }),
  );
  testWidgets(
    'regiao nao vira ponto exato sem ajuste',
    (tester) => comTiles(tester, () async {
      await abrir(
        tester,
        local: const LocalizacaoSelecionada(
          ponto: LatLng(-21, -50),
          endereco: 'Araçatuba',
          precisao: PrecisaoLocalizacao.regiao,
          pontoEspecifico: false,
        ),
      );
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      expect(resultado, isNull);
      expect(find.byType(TesteMapa), findsOneWidget);
    }),
  );
  testWidgets(
    'falha do endereco reverso nao inventa numero solicitado',
    (tester) => comTiles(tester, () async {
      enderecos.falhar = true;
      await abrir(tester);
      await marcar(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('CONFIRMAR LOCAL'));
      await tester.pumpAndSettle();
      expect(resultado!.ponto, novo);
      expect(resultado!.numero, isNull);
      expect(resultado!.endereco, 'Endereço não encontrado');
      expect(resultado!.exigeAjusteNoMapa, false);
    }),
  );
  testWidgets(
    'sair durante geocodificacao nao atualiza tela removida',
    (tester) => comTiles(tester, () async {
      final pendente = Completer<LocalizacaoSelecionada?>();
      enderecos.pendente = pendente.future;
      await abrir(tester);
      tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        novo,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      pendente.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(resultado, isNull);
    }),
  );
}
