import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/campus_destino_service.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';
import 'package:uni_carona/widgets/formulario_ofertar_carona.dart';

const cidadeA = CidadeCampus('Araçatuba', 'SP');
const referenciaA = LocalizacaoSelecionada(
  ponto: LatLng(-21.2, -50.4),
  endereco: 'Araçatuba, SP',
  cidade: 'Araçatuba',
  estado: 'São Paulo',
);
const referenciaB = LocalizacaoSelecionada(
  ponto: LatLng(-23.5, -46.6),
  endereco: 'São Paulo, SP',
  cidade: 'São Paulo',
  estado: 'SP',
);
const campi = [
  CampusDestino(
    idCampus: 1,
    idInstituicao: 1,
    nome: 'Centro Salesiano',
    sigla: 'UNISALESIANO',
    campus: 'Araçatuba',
    cidade: cidadeA,
    ponto: LatLng(-21.23, -50.4),
  ),
  CampusDestino(
    idCampus: 2,
    idInstituicao: 2,
    nome: 'Universidade Estadual Paulista',
    sigla: 'UNESP',
    campus: 'Odontologia',
    cidade: cidadeA,
    ponto: LatLng(-21.2, -50.4),
  ),
  CampusDestino(
    idCampus: 3,
    idInstituicao: 2,
    nome: 'Universidade Estadual Paulista',
    sigla: 'UNESP',
    campus: 'Veterinária',
    cidade: cidadeA,
    ponto: LatLng(-21.18, -50.43),
  ),
];

class CatalogoTeste extends CampusDestinoService {
  CidadeCampus? cidadeDetectada = cidadeA;
  Future<CidadeCampus?>? deteccao;
  final buscas = <CidadeCampus>[];
  Future<List<CampusDestino>> Function(CidadeCampus cidade)? resposta;
  @override
  Future<CidadeCampus?> identificarCidade() =>
      deteccao ?? Future.value(cidadeDetectada);
  @override
  Future<List<CampusDestino>> listar(
    CidadeCampus cidade, {
    Duration prazo = const Duration(seconds: 20),
  }) {
    buscas.add(cidade);
    return resposta?.call(cidade) ?? Future.value(campi);
  }
}

class EnderecosTeste extends EnderecoService {
  final buscas = <String>[];
  final referencias = <(double?, double?)>[];
  Future<List<LocalizacaoSelecionada>> Function(String texto)? resposta;
  @override
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado, {
    double? latitudeReferencia,
    double? longitudeReferencia,
    String? cidadeReferencia,
    String? estadoReferencia,
  }) {
    buscas.add(enderecoDigitado);
    referencias.add((latitudeReferencia, longitudeReferencia));
    return resposta?.call(enderecoDigitado) ?? Future.value([]);
  }
}

Future<void> montar(
  WidgetTester tester, {
  required TextEditingController controller,
  required CatalogoTeste catalogo,
  EnderecosTeste? enderecos,
  LocalizacaoSelecionada? referencia,
  ValueChanged<LocalizacaoSelecionada>? selecionar,
  ValueChanged<String>? alterar,
  bool mostrarAoAbrir = true,
  bool visualAtualizado = false,
  bool selecionarCidadeNaLista = false,
  double escala = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(escala)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CampoDestinoCampus(
              controller: controller,
              campusService: catalogo,
              enderecoService: enderecos ?? EnderecosTeste(),
              referenciaInicial: referencia,
              mostrarAoAbrir: mostrarAoAbrir,
              visualAtualizado: visualAtualizado,
              selecionarCidadeNaLista: selecionarCidadeNaLista,
              onSelecionado: selecionar ?? (_) {},
              onChanged: alterar,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late TextEditingController controller;
  late CatalogoTeste catalogo;
  late EnderecosTeste enderecos;
  setUp(() {
    controller = TextEditingController();
    catalogo = CatalogoTeste();
    enderecos = EnderecosTeste();
  });
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }

  for (final configuracao in [(true, true), (true, false), (false, true)]) {
    testWidgets(
      'cabecalho de cidade respeita visual e seletor: $configuracao',
      (tester) async {
        await montar(
          tester,
          controller: controller,
          catalogo: catalogo,
          visualAtualizado: configuracao.$1,
          selecionarCidadeNaLista: configuracao.$2,
        );
        await tester.pumpAndSettle();
        final moderno = configuracao.$1;
        expect(find.text('Alterar'), moderno ? findsOneWidget : findsNothing);
        expect(
          find.byIcon(Icons.location_city_outlined),
          moderno ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(moderno ? 'Araçatuba, SP' : 'Faculdades em Araçatuba/SP'),
          findsOneWidget,
        );
        expect(find.byTooltip('Alterar cidade'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await fechar(tester);
      },
    );
  }

  for (final estreita in [false, true]) {
    testWidgets(
      'oferta reaproveita controle de cidade e mantem destino e mapa: estreita=$estreita',
      (tester) async {
        tester.view.physicalSize = Size(estreita ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final campos = List.generate(6, (_) => TextEditingController());
        campos[0].text = 'UNESP · Odontologia';
        addTearDown(() {
          for (final campo in campos) {
            campo.dispose();
          }
          AuthService.tokenUsuarioLogado = null;
        });
        AuthService.tokenUsuarioLogado = 'token-sintetico';
        var publicacoes = 0;
        var destinos = 0;
        var mapas = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(estreita ? 1.8 : 1)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: FormularioOfertarCarona(
                      destinoController: campos[0],
                      dataController: campos[1],
                      horarioController: campos[2],
                      vagasController: campos[3],
                      valorController: campos[4],
                      observacoesController: campos[5],
                      caronaRecorrente: false,
                      enviandoCarona: false,
                      diasSelecionados: const [],
                      pontosEmbarque: const [],
                      referenciaDestino: referenciaA,
                      pontosEmbarqueEditaveis: true,
                      possuiVeiculo: true,
                      onSelecionarDestino: () => mapas++,
                      onSelecionarData: () {},
                      onSelecionarHorario: () {},
                      onAdicionarPontoEmbarque: () {},
                      onRemoverPontoEmbarque: (_) {},
                      onOfertarCarona: () => publicacoes++,
                      onCadastrarVeiculo: () {},
                      onDestinoChanged: (_) {},
                      onDestinoSelecionado: (_) => destinos++,
                      onRecorrenciaChanged: (_) {},
                      onDiaSelecionado: (_) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final destino = find.descendant(
              of: find.byType(CampoDestinoCampus),
              matching: find.byType(TextField),
            );
            await tester.ensureVisible(destino);
            await tester.pumpAndSettle();
            await tester.tap(destino);
            await tester.pumpAndSettle();
            expect(find.text('Araçatuba, SP'), findsOneWidget);
            expect(find.text('Alterar'), findsOneWidget);
            expect(find.byIcon(Icons.location_city_outlined), findsNothing);
            expect(find.byTooltip('Escolher destino no mapa'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.ensureVisible(find.text('Alterar'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Alterar'));
            await tester.pumpAndSettle();
            expect(find.text('Cidade das faculdades'), findsOneWidget);
            expect(
              tester
                  .widget<TextFormField>(find.byType(TextFormField).first)
                  .initialValue,
              'Araçatuba',
            );
            await tester.enterText(
              find.byType(TextFormField).first,
              'Campinas',
            );
            await tester.ensureVisible(find.text('Aplicar'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Aplicar'));
            await tester.pumpAndSettle();
            expect(find.text('Campinas, SP'), findsOneWidget);
            expect(campos[0].text, 'UNESP · Odontologia');
            expect(publicacoes, 0);
            expect(destinos, 0);
            expect(mapas, 0);
            await tester.ensureVisible(
              find.byTooltip('Escolher destino no mapa'),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Escolher destino no mapa'));
            expect(mapas, 1);
            expect(tester.takeException(), isNull);
            await fechar(tester);
          },
          () => MockClient(
            (_) async => http.Response('{"sucesso":true,"dados":[]}', 200),
          ),
        );
      },
    );
  }

  testWidgets('cabecalho compartilhado acomoda cidade longa em tela estreita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    catalogo.cidadeDetectada = const CidadeCampus(
      'São José do Vale do Rio Preto',
      'RJ',
    );
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      visualAtualizado: true,
      selecionarCidadeNaLista: true,
      escala: 1.8,
    );
    await tester.pumpAndSettle();
    expect(find.text('São José do Vale do Rio Preto, RJ'), findsOneWidget);
    expect(find.text('Alterar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final cidade = tester.getRect(
      find.text('São José do Vale do Rio Preto, RJ'),
    );
    final alterar = tester.getRect(find.text('Alterar'));
    expect(cidade.right, lessThanOrEqualTo(alterar.left));
    expect(alterar.right, lessThanOrEqualTo(320));
    await fechar(tester);
  });

  testWidgets(
    'cabecalho compartilhado permite escolher cidade sem GPS disponivel',
    (tester) async {
      catalogo.cidadeDetectada = null;
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        visualAtualizado: true,
        selecionarCidadeNaLista: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Selecionar cidade'), findsOneWidget);
      expect(find.text('Alterar'), findsOneWidget);
      expect(find.byTooltip('Alterar cidade'), findsOneWidget);
      expect(
        find.text('Localização indisponível. Selecione uma cidade.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await fechar(tester);
    },
  );

  for (final tipo in TipoFalhaEndereco.values) {
    testWidgets(
      'destino diferencia $tipo e preserva campi durante nova tentativa',
      (tester) async {
        enderecos.resposta = (_) async {
          if (enderecos.buscas.length == 1) throw FalhaBuscaEndereco(tipo);
          return [];
        };
        await montar(
          tester,
          controller: controller,
          catalogo: catalogo,
          enderecos: enderecos,
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'unesp');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.text(FalhaBuscaEndereco(tipo).mensagem), findsOneWidget);
        expect(find.textContaining('Nenhum endereço encontrado'), findsNothing);
        expect(find.textContaining('UNESP · Odontologia'), findsOneWidget);
        expect(find.textContaining('UNESP · Veterinária'), findsOneWidget);
        await tester.ensureVisible(find.text('Tentar novamente'));
        await tester.tap(find.text('Tentar novamente'));
        await tester.pumpAndSettle();
        expect(enderecos.buscas, ['unesp', 'unesp']);
        expect(find.text('Tentar novamente'), findsNothing);
        expect(controller.text, 'unesp');
        expect(tester.takeException(), isNull);
        await fechar(tester);
      },
    );
  }

  testWidgets('GPS identificado conserva ponto de referencia para pesquisa', (
    tester,
  ) async {
    catalogo.cidadeDetectada = const CidadeCampus(
      'Araçatuba',
      'SP',
      pontoReferencia: LatLng(-21.2, -50.4),
    );
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(enderecos.referencias.single, (-21.2, -50.4));
    await fechar(tester);
  });

  testWidgets('erro antigo de endereco nao afeta consulta nova', (
    tester,
  ) async {
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    enderecos.resposta = (texto) =>
        texto == 'antiga' ? pendente.future : Future.value([]);
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'antiga');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'nova rua');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    pendente.completeError(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.textContaining('Nenhum endereço encontrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });

  testWidgets('troca manual de cidade descarta GPS anterior e erro pendente', (
    tester,
  ) async {
    catalogo.cidadeDetectada = const CidadeCampus(
      'Araçatuba',
      'SP',
      pontoReferencia: LatLng(-21.2, -50.4),
    );
    catalogo.resposta = (_) async => [];
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    enderecos.resposta = (_) =>
        enderecos.buscas.length == 1 ? pendente.future : Future.value([]);
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).first, 'Campinas');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    pendente.completeError(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    await tester.pumpAndSettle();
    expect(enderecos.referencias, [(-21.2, -50.4), (null, null)]);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Faculdades em Campinas/SP'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });

  testWidgets('aviso da pesquisa cabe em tela estreita e fonte grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    enderecos.resposta = (_) async =>
        throw const FalhaBuscaEndereco(TipoFalhaEndereco.conexao);
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
      escala: 1.8,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tentar novamente'));
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });

  testWidgets('lista campi ao abrir sem nenhuma letra', (tester) async {
    await montar(tester, controller: controller, catalogo: catalogo);
    expect(controller.text, isEmpty);
    expect(find.text(campi[0].titulo), findsOneWidget);
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
    await fechar(tester);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
      'formulário exibe endereço e seleciona campus diretamente com fonte $escala',
      (tester) async {
        const campus = CampusDestino(
          idCampus: 589,
          idInstituicao: 588,
          nome: 'Centro Universitário Toledo',
          sigla: 'UniToledo Wyden',
          campus: 'Araçatuba',
          rotuloUnidade: 'Jardim Sumaré',
          enderecoCompleto: 'Rua Antônio Afonso de Toledo, 595 - Jardim Sumaré',
          cidade: cidadeA,
          ponto: LatLng(-21.21307520, -50.43053199),
        );
        catalogo.resposta = (_) async => [campus];
        LocalizacaoSelecionada? escolhido;
        await montar(
          tester,
          controller: controller,
          catalogo: catalogo,
          enderecos: enderecos,
          escala: escala,
          selecionar: (local) => escolhido = local,
        );
        expect(find.text(campus.titulo), findsOneWidget);
        expect(find.text(campus.descricaoEndereco), findsOneWidget);
        await tester.ensureVisible(find.text(campus.titulo));
        await tester.tap(find.text(campus.titulo));
        await tester.pumpAndSettle();
        expect(escolhido!.ponto, campus.ponto);
        expect(escolhido!.endereco, contains('595'));
        expect(escolhido!.nome, campus.titulo);
        expect(enderecos.buscas, isEmpty);
        expect(tester.takeException(), isNull);
        await fechar(tester);
      },
    );
  }

  testWidgets('filtra unidades distintas por rua e número sem misturá-las', (
    tester,
  ) async {
    const primeiro = CampusDestino(
      idCampus: 10,
      idInstituicao: 1,
      nome: 'Universidade Estadual',
      sigla: 'UE',
      campus: 'Campus I',
      rotuloUnidade: 'Centro',
      enderecoCompleto: 'Rua José Bonifácio, 1193',
      cidade: cidadeA,
      ponto: LatLng(-21.2, -50.4),
    );
    const segundo = CampusDestino(
      idCampus: 11,
      idInstituicao: 1,
      nome: 'Universidade Estadual',
      sigla: 'UE',
      campus: 'Campus II',
      rotuloUnidade: 'Rodovia',
      enderecoCompleto: 'Rodovia Marechal Rondon, km 527',
      cidade: cidadeA,
      ponto: LatLng(-21.25, -50.42),
    );
    catalogo.resposta = (_) async => [primeiro, segundo];
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    expect(find.text(primeiro.titulo), findsOneWidget);
    expect(find.text(segundo.titulo), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'jose 1193');
    await tester.pump();
    expect(find.text(primeiro.titulo), findsOneWidget);
    expect(find.text(segundo.titulo), findsNothing);
    await fechar(tester);
  });

  testWidgets(
    'sem ponto usa o endereço cadastrado na busca e continua pedindo confirmação',
    (tester) async {
      const campus = CampusDestino(
        idCampus: 1707,
        idInstituicao: 1706,
        nome: 'Faculdade de Tecnologia',
        sigla: 'Fatec',
        campus: 'Araçatuba',
        rotuloUnidade: 'Prof. Fernando Amaral',
        enderecoCompleto: 'Avenida Prestes Maia, 1764',
        cidade: cidadeA,
      );
      catalogo.resposta = (_) async => [campus];
      var selecionou = false;
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        enderecos: enderecos,
        selecionar: (_) => selecionou = true,
      );
      await tester.tap(find.text(campus.titulo));
      await tester.pumpAndSettle();
      expect(enderecos.buscas, ['Avenida Prestes Maia, 1764, Araçatuba SP']);
      expect(selecionou, isFalse);
      expect(find.textContaining('Confirme o endereço'), findsOneWidget);
      await fechar(tester);
    },
  );

  testWidgets('filtra desde a primeira letra e restaura ao apagar', (
    tester,
  ) async {
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.enterText(find.byType(TextField), 'v');
    await tester.pump();
    expect(find.text(campi[0].titulo), findsNothing);
    expect(find.text(campi[1].titulo), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'od');
    await tester.pump();
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(find.text(campi[2].titulo), findsNothing);
    expect(enderecos.buscas, isEmpty);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text(campi[0].titulo), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
    await fechar(tester);
  });

  testWidgets('filtra sigla e campus ignorando caixa e acentos', (
    tester,
  ) async {
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.enterText(find.byType(TextField), 'unesp VETERINARIA');
    await tester.pump();
    expect(find.text(campi[2].titulo), findsOneWidget);
    expect(find.text(campi[1].titulo), findsNothing);
    await fechar(tester);
  });

  testWidgets(
    'não altera o destino salvo nem filtra a lista pelo texto antigo ao abrir',
    (tester) async {
      controller.text = 'Destino já salvo';
      final alteracoes = <String>[];
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        alterar: alteracoes.add,
      );
      expect(controller.text, 'Destino já salvo');
      expect(find.text(campi[0].titulo), findsOneWidget);
      expect(alteracoes, isEmpty);
      await fechar(tester);
    },
  );

  testWidgets(
    'seleciona o ponto cadastrado sem buscar endereço nem modificar o outro campus',
    (tester) async {
      LocalizacaoSelecionada? escolhido;
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        enderecos: enderecos,
        selecionar: (local) => escolhido = local,
      );
      await tester.tap(find.text(campi[1].titulo));
      await tester.pump();
      expect(escolhido!.ponto, campi[1].ponto);
      expect(escolhido!.ponto, isNot(campi[2].ponto));
      expect(controller.text, escolhido!.descricaoCompleta);
      expect(enderecos.buscas, isEmpty);
      await fechar(tester);
    },
  );

  testWidgets('nos formulários só carrega ao tocar no destino', (tester) async {
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      mostrarAoAbrir: false,
    );
    expect(catalogo.buscas, isEmpty);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(catalogo.buscas, hasLength(1));
    expect(find.text(campi[0].titulo), findsOneWidget);
    await fechar(tester);
  });

  testWidgets(
    'falha de rede oferece nova tentativa sem falso aviso de lista vazia',
    (tester) async {
      catalogo.resposta = (_) async => throw StateError('Offline');
      await montar(tester, controller: controller, catalogo: catalogo);
      expect(
        find.text('Não foi possível carregar as faculdades.'),
        findsOneWidget,
      );
      expect(
        find.text('Nenhuma faculdade cadastrada nesta cidade.'),
        findsNothing,
      );
      catalogo.resposta = (_) async => campi;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text(campi[0].titulo), findsOneWidget);
      expect(
        find.text('Não foi possível carregar as faculdades.'),
        findsNothing,
      );
      await fechar(tester);
    },
  );

  testWidgets('lista realmente vazia tem aviso próprio', (tester) async {
    catalogo.resposta = (_) async => [];
    await montar(tester, controller: controller, catalogo: catalogo);
    expect(
      find.text('Nenhuma faculdade cadastrada nesta cidade.'),
      findsOneWidget,
    );
    expect(find.text('Não foi possível carregar as faculdades.'), findsNothing);
    await fechar(tester);
  });

  testWidgets('sem GPS permite escolher cidade e estado fora de SP', (
    tester,
  ) async {
    catalogo.cidadeDetectada = null;
    catalogo.resposta = (_) async => [];
    await montar(tester, controller: controller, catalogo: catalogo);
    expect(find.textContaining('Localização indisponível'), findsOneWidget);
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Rio Branco');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC · Acre').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(catalogo.buscas.single.cidade, 'Rio Branco');
    expect(catalogo.buscas.single.uf, 'AC');
    expect(find.text('Faculdades em Rio Branco/AC'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('valida cidade e estado e cancelar não modifica a pesquisa', (
    tester,
  ) async {
    catalogo.cidadeDetectada = null;
    await montar(tester, controller: controller, catalogo: catalogo);
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe a cidade'), findsOneWidget);
    expect(find.text('Selecione o estado'), findsOneWidget);
    expect(catalogo.buscas, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(catalogo.buscas, isEmpty);
    await fechar(tester);
  });

  testWidgets('resposta atrasada da cidade antiga não substitui a nova', (
    tester,
  ) async {
    final antiga = Completer<List<CampusDestino>>();
    final nova = Completer<List<CampusDestino>>();
    catalogo.resposta = (cidade) =>
        cidade.cidade == 'Araçatuba' ? antiga.future : nova.future;
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      referencia: referenciaA,
    );
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      referencia: referenciaB,
    );
    nova.complete([]);
    await tester.pump();
    antiga.complete(campi);
    await tester.pumpAndSettle();
    expect(find.text('Faculdades em São Paulo/SP'), findsOneWidget);
    expect(find.text(campi[0].titulo), findsNothing);
    await fechar(tester);
  });

  testWidgets('GPS atrasado não desfaz a cidade escolhida manualmente', (
    tester,
  ) async {
    final gps = Completer<CidadeCampus?>();
    catalogo.deteccao = gps.future;
    catalogo.resposta = (_) async => [];
    await montar(tester, controller: controller, catalogo: catalogo);
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).first, 'Rio Branco');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('AC · Acre').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    gps.complete(cidadeA);
    await tester.pumpAndSettle();
    expect(catalogo.buscas, hasLength(1));
    expect(catalogo.buscas.single.uf, 'AC');
    await fechar(tester);
  });

  testWidgets('ignora endereço atrasado após apagar ou mudar o texto', (
    tester,
  ) async {
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    enderecos.resposta = (_) => pendente.future;
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.enterText(find.byType(TextField), 'Rua antiga');
    await tester.pump(const Duration(milliseconds: 501));
    await tester.enterText(find.byType(TextField), '');
    pendente.complete([referenciaB]);
    await tester.pumpAndSettle();
    expect(find.text('São Paulo, SP'), findsNothing);
    expect(find.text(campi[0].titulo), findsOneWidget);
    await fechar(tester);
  });

  testWidgets(
    'campus sem coordenadas exige confirmação e rejeita cidade genérica ou outra cidade',
    (tester) async {
      final semPonto = CampusDestino(
        idCampus: 4,
        idInstituicao: 4,
        nome: 'Faculdade de Tecnologia',
        sigla: 'FATEC',
        campus: 'Araçatuba',
        cidade: cidadeA,
      );
      catalogo.resposta = (_) async => [semPonto];
      const local = LocalizacaoSelecionada(
        ponto: LatLng(-21.2, -50.4),
        nome: 'Fatec',
        endereco: 'Rua da faculdade, 10',
        cidade: 'Araçatuba',
        estado: 'SP',
      );
      enderecos.resposta = (_) async => [
        local,
        referenciaB,
        const LocalizacaoSelecionada(
          ponto: LatLng(-21.2, -50.4),
          nome: 'Centro da cidade',
          endereco: 'Cidade',
          cidade: 'Araçatuba',
          estado: 'SP',
          pontoEspecifico: false,
        ),
      ];
      LocalizacaoSelecionada? selecionado;
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        enderecos: enderecos,
        selecionar: (valor) => selecionado = valor,
      );
      await tester.tap(find.text(semPonto.titulo));
      await tester.pumpAndSettle();
      expect(selecionado, isNull);
      expect(find.textContaining('Confirme o endereço'), findsOneWidget);
      expect(find.text('Centro da cidade'), findsNothing);
      expect(find.text('São Paulo, SP'), findsNothing);
      await tester.tap(find.text('Fatec'));
      await tester.pump();
      expect(selecionado, same(local));
      await fechar(tester);
    },
  );

  testWidgets(
    'busca de outros endereços funciona mesmo com catálogo fora do ar',
    (tester) async {
      catalogo.resposta = (_) async => throw StateError('Offline');
      enderecos.resposta = (_) async => [referenciaB];
      LocalizacaoSelecionada? selecionado;
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        enderecos: enderecos,
        selecionar: (local) => selecionado = local,
      );
      await tester.enterText(find.byType(TextField), 'Rua exemplo');
      await tester.pump(const Duration(milliseconds: 501));
      await tester.pumpAndSettle();
      await tester.tap(find.text('São Paulo, SP'));
      await tester.pump();
      expect(selecionado, referenciaB);
      await fechar(tester);
    },
  );

  testWidgets('sair durante carregamento não causa setState após dispose', (
    tester,
  ) async {
    final pendente = Completer<List<CampusDestino>>();
    catalogo.resposta = (_) => pendente.future;
    await montar(tester, controller: controller, catalogo: catalogo);
    await fechar(tester);
    pendente.complete(campi);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('digitação durante carregamento já filtra os campi recebidos', (
    tester,
  ) async {
    final pendente = Completer<List<CampusDestino>>();
    catalogo.resposta = (_) => pendente.future;
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      enderecos: enderecos,
    );
    await tester.enterText(find.byType(TextField), 'od');
    pendente.complete(campi);
    await tester.pumpAndSettle();
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(find.text(campi[0].titulo), findsNothing);
    expect(enderecos.buscas, isEmpty);
    await fechar(tester);
  });

  testWidgets('trocar cidade remove a lista anterior enquanto a nova carrega', (
    tester,
  ) async {
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      referencia: referenciaA,
    );
    expect(find.text(campi[0].titulo), findsOneWidget);
    final pendente = Completer<List<CampusDestino>>();
    catalogo.resposta = (_) => pendente.future;
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      referencia: referenciaB,
    );
    expect(find.text(campi[0].titulo), findsNothing);
    expect(find.text('Faculdades em São Paulo/SP'), findsOneWidget);
    pendente.complete([]);
    await tester.pumpAndSettle();
    await fechar(tester);
  });

  testWidgets('trocar cidade no formulário mantém as sugestões abertas', (
    tester,
  ) async {
    await montar(
      tester,
      controller: controller,
      catalogo: catalogo,
      mostrarAoAbrir: false,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Alterar cidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Lins');
    catalogo.resposta = (_) async => [];
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Faculdades em Lins/SP'), findsOneWidget);
    expect(find.text(campi[0].titulo), findsNothing);
    await fechar(tester);
  });

  testWidgets(
    'limpar pelo botão restaura a lista e notifica o filtro da carona',
    (tester) async {
      final alteracoes = <String>[];
      await montar(
        tester,
        controller: controller,
        catalogo: catalogo,
        alterar: alteracoes.add,
      );
      await tester.enterText(find.byType(TextField), 'od');
      await tester.pump();
      await tester.tap(find.byTooltip('Limpar destino'));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(alteracoes.last, '');
      expect(find.text(campi[0].titulo), findsOneWidget);
      await fechar(tester);
    },
  );

  testWidgets('tela estreita e fonte ampliada não causam overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await montar(tester, controller: controller, catalogo: catalogo, escala: 2);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });
}
