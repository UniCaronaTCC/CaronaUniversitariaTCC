import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/selecionar_destino.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/catalogo_cidades_service.dart';
import 'package:uni_carona/services/cidade_pesquisa_service.dart';
import 'package:uni_carona/services/destino_preferido_service.dart';

import 'campo_destino_campus_test.dart'
    show CatalogoTeste, EnderecosTeste, campi, referenciaA;

const birigui = CidadeCampus('Birigui', 'SP');

class CidadesTeste extends CatalogoCidadesService {
  const CidadesTeste();
  @override
  Future<List<CidadeCampus>> listar() async => const [
    CidadeCampus('Araçatuba', 'SP'),
    birigui,
    CidadeCampus('Manaus', 'AM'),
    CidadeCampus('Rio Branco', 'AC'),
  ];
}

class PreferenciaTeste extends CidadePesquisaService {
  Future<CidadeCampus?>? leitura;
  bool falharGravacao = false;
  @override
  Future<CidadeCampus?> carregar(int idUsuario) =>
      leitura ?? super.carregar(idUsuario);
  @override
  Future<void> salvar(int idUsuario, CidadeCampus cidade) async {
    if (falharGravacao) throw StateError('armazenamento indisponivel');
    await super.salvar(idUsuario, cidade);
  }
}

Future<void> montar(
  WidgetTester tester,
  CatalogoTeste campiService, {
  int id = 7,
  CidadePesquisaService preferencia = const CidadePesquisaService(),
  LocalizacaoSelecionada? referencia = referenciaA,
  LocalizacaoSelecionada? destino,
  EnderecosTeste? enderecos,
  ValueChanged<LocalizacaoSelecionada?>? retorno,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final local = await Navigator.of(context)
                  .push<LocalizacaoSelecionada>(
                    MaterialPageRoute(
                      builder: (_) => SelecionarDestinoTela(
                        idUsuario: id,
                        localizacaoReferencia: referencia,
                        destinoInicial: destino,
                        campusService: campiService,
                        enderecoService: enderecos ?? EnderecosTeste(),
                        cidadePesquisaService: preferencia,
                        catalogoCidadesService: const CidadesTeste(),
                      ),
                    ),
                  );
              retorno?.call(local);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> abrirCidades(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Alterar cidade'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Future<void> escolherBirigui(WidgetTester tester) async {
  await abrirCidades(tester);
  await tester.enterText(
    find.byKey(const ValueKey('pesquisa-cidade')),
    'birig',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('cidade-Birigui-SP')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preferencia = CidadePesquisaService();
  late CatalogoTeste catalogo;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    catalogo = CatalogoTeste();
    catalogo.resposta = (cidade) async =>
        cidade.cidade == 'Araçatuba' ? campi : [];
  });

  testWidgets(
    'destino salvo nao e confundido com GPS quando localizacao falha',
    (tester) async {
      catalogo.cidadeDetectada = null;
      await montar(
        tester,
        catalogo,
        referencia: null,
        destino: campi[1].localizacao,
      );
      await tester.pumpAndSettle();
      expect(find.text('Selecionar cidade'), findsOneWidget);
      expect(find.textContaining('Localização indisponível'), findsOneWidget);
      expect(catalogo.buscas, isEmpty);
    },
  );

  testWidgets(
    'falha ao salvar nao prende busca de endereco que estava pendente',
    (tester) async {
      final primeira = Completer<List<LocalizacaoSelecionada>>();
      final enderecos = EnderecosTeste();
      enderecos.resposta = (_) =>
          enderecos.buscas.length == 1 ? primeira.future : Future.value([]);
      await montar(
        tester,
        catalogo,
        enderecos: enderecos,
        preferencia: PreferenciaTeste()..falharGravacao = true,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Rua teste');
      await tester.pump(const Duration(milliseconds: 501));
      expect(enderecos.buscas, hasLength(1));
      await escolherBirigui(tester);
      await tester.enterText(find.byType(TextField), 'Rua nova');
      await tester.pump(const Duration(milliseconds: 501));
      primeira.complete([]);
      await tester.pumpAndSettle();
      expect(enderecos.buscas, hasLength(2));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'falha ao salvar durante carga dos campi oferece tentar novamente',
    (tester) async {
      final primeira = Completer<List<CampusDestino>>();
      catalogo.resposta = (_) =>
          catalogo.buscas.length == 1 ? primeira.future : Future.value(campi);
      await montar(
        tester,
        catalogo,
        preferencia: PreferenciaTeste()..falharGravacao = true,
      );
      await escolherBirigui(tester);
      expect(
        find.text('Não foi possível atualizar as faculdades.'),
        findsOneWidget,
      );
      expect(
        find.text('Nenhuma faculdade cadastrada nesta cidade.'),
        findsNothing,
      );
      await tester.tap(find.text('Tentar novamente'));
      primeira.complete([]);
      await tester.pumpAndSettle();
      expect(find.text(campi[1].titulo), findsOneWidget);
    },
  );

  testWidgets('lista cidades antes de digitar e filtra sem acento', (
    tester,
  ) async {
    await montar(tester, catalogo);
    await tester.pumpAndSettle();
    await abrirCidades(tester);
    expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
    expect(find.byKey(const ValueKey('cidade-Birigui-SP')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-cidade')),
      'ARACATUBA',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('cidade-Araçatuba-SP')), findsOneWidget);
    expect(find.byKey(const ValueKey('cidade-Birigui-SP')), findsNothing);
    await tester.tap(find.byTooltip('Fechar cidades'));
    await tester.pumpAndSettle();
    expect(await preferencia.carregar(7), isNull);
  });

  testWidgets('salva cidade ao escolher e restaura ao reabrir', (tester) async {
    await montar(tester, catalogo);
    await tester.pumpAndSettle();
    await escolherBirigui(tester);
    expect(find.text('Birigui, SP'), findsOneWidget);
    expect((await preferencia.carregar(7))!.mesmaCidade(birigui), isTrue);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Birigui, SP'), findsOneWidget);
    expect(catalogo.buscas.last.mesmaCidade(birigui), isTrue);
  });

  testWidgets(
    'mudar cidade limpa pesquisa mas preserva destino confirmado ao voltar',
    (tester) async {
      const destinos = DestinoPreferidoService();
      final destino = campi[1].localizacao!;
      await destinos.salvar(7, destino);
      LocalizacaoSelecionada? retorno;
      await montar(
        tester,
        catalogo,
        destino: destino,
        retorno: (local) => retorno = local,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'UNESP');
      await tester.pump(const Duration(milliseconds: 600));
      await escolherBirigui(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        find.text('Nenhuma faculdade cadastrada nesta cidade.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(retorno, isNull);
      expect((await destinos.carregar(7))!.toJson(), destino.toJson());
    },
  );

  testWidgets('outra conta inicia no automatico sem herdar a cidade', (
    tester,
  ) async {
    await preferencia.salvar(99, birigui);
    await montar(tester, catalogo);
    await tester.pumpAndSettle();
    expect(find.text('Araçatuba, SP'), findsWidgets);
    expect((await preferencia.carregar(99))!.cidade, 'Birigui');
    expect(await preferencia.carregar(7), isNull);
  });

  testWidgets('voltar ao GPS remove preferencia e conserva destino salvo', (
    tester,
  ) async {
    await preferencia.salvar(7, birigui);
    final destino = campi[1].localizacao!;
    await const DestinoPreferidoService().salvar(7, destino);
    await montar(tester, catalogo);
    await tester.pumpAndSettle();
    expect(find.text('Birigui, SP'), findsOneWidget);
    await abrirCidades(tester);
    await tester.tap(find.text('Usar localização atual'));
    await tester.pumpAndSettle();
    expect(find.text('Araçatuba, SP'), findsWidgets);
    expect(await preferencia.carregar(7), isNull);
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(
      (await const DestinoPreferidoService().carregar(7))!.toJson(),
      destino.toJson(),
    );
  });

  testWidgets('GPS indisponivel nao apaga preferencia nem troca a cidade', (
    tester,
  ) async {
    await preferencia.salvar(7, birigui);
    catalogo.cidadeDetectada = null;
    await montar(tester, catalogo);
    await tester.pumpAndSettle();
    await abrirCidades(tester);
    await tester.tap(find.text('Usar localização atual'));
    await tester.pumpAndSettle();
    expect(find.text('Birigui, SP'), findsOneWidget);
    expect((await preferencia.carregar(7))!.mesmaCidade(birigui), isTrue);
    expect(
      find.text('Não foi possível identificar sua cidade.'),
      findsOneWidget,
    );
  });

  testWidgets('erro ao salvar mantem cidade anterior e avisa', (tester) async {
    final lenta = PreferenciaTeste()..falharGravacao = true;
    await montar(tester, catalogo, preferencia: lenta);
    await tester.pumpAndSettle();
    await escolherBirigui(tester);
    expect(find.text('Araçatuba, SP'), findsWidgets);
    expect(await preferencia.carregar(7), isNull);
    expect(
      find.text('Não foi possível alterar sua cidade. Tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('preferencia antiga atrasada nao sobrescreve escolha nova', (
    tester,
  ) async {
    final pendente = Completer<CidadeCampus?>();
    final lenta = PreferenciaTeste()..leitura = pendente.future;
    await montar(tester, catalogo, preferencia: lenta);
    await escolherBirigui(tester);
    pendente.complete(const CidadeCampus('Manaus', 'AM'));
    await tester.pumpAndSettle();
    expect(find.text('Birigui, SP'), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
  });

  testWidgets('GPS antigo atrasado nao sobrescreve escolha nova', (
    tester,
  ) async {
    final gps = Completer<CidadeCampus?>();
    catalogo.deteccao = gps.future;
    await montar(tester, catalogo, referencia: null);
    await escolherBirigui(tester);
    gps.complete(const CidadeCampus('Manaus', 'AM'));
    await tester.pumpAndSettle();
    expect(find.text('Birigui, SP'), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
  });

  testWidgets(
    'consulta de campi antiga nao mistura resultados da nova cidade',
    (tester) async {
      final pendente = Completer<List<CampusDestino>>();
      catalogo.resposta = (cidade) =>
          cidade.cidade == 'Araçatuba' ? pendente.future : Future.value([]);
      await montar(tester, catalogo);
      await escolherBirigui(tester);
      pendente.complete(campi);
      await tester.pumpAndSettle();
      expect(find.text('Birigui, SP'), findsOneWidget);
      expect(find.text(campi[1].titulo), findsNothing);
    },
  );

  testWidgets('fechar durante restauracao nao causa escrita ou erro de tela', (
    tester,
  ) async {
    final pendente = Completer<CidadeCampus?>();
    await montar(
      tester,
      catalogo,
      preferencia: PreferenciaTeste()..leitura = pendente.future,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pendente.complete(birigui);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await preferencia.carregar(7), isNull);
  });
}
