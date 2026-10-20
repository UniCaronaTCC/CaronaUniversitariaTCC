import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/models/campus_destino.dart';
import 'package:uni_carona/services/campus_destino_service.dart';
import 'package:uni_carona/widgets/campo_destino_campus.dart';

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

  testWidgets('lista campi ao abrir sem nenhuma letra', (tester) async {
    await montar(tester, controller: controller, catalogo: catalogo);
    expect(controller.text, isEmpty);
    expect(find.text(campi[0].titulo), findsOneWidget);
    expect(find.text(campi[1].titulo), findsOneWidget);
    expect(catalogo.buscas, hasLength(1));
    await fechar(tester);
  });

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
