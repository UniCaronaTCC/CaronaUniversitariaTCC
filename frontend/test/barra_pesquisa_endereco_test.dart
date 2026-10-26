import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/models/localizacao_selecionada.dart';
import 'package:uni_carona/mapa/services/endereco_service.dart';
import 'package:uni_carona/mapa/widgets/barra_pesquisa_endereco.dart';

class _EnderecoServiceFalso extends EnderecoService {
  final List<LocalizacaoSelecionada> resultados;
  int quantidadeBuscas = 0;
  Future<List<LocalizacaoSelecionada>> Function(String texto)? resposta;

  _EnderecoServiceFalso(this.resultados);

  @override
  Future<List<LocalizacaoSelecionada>> buscarLocalizacoesPorEndereco(
    String enderecoDigitado, {
    double? latitudeReferencia,
    double? longitudeReferencia,
    String? cidadeReferencia,
    String? estadoReferencia,
  }) async {
    quantidadeBuscas++;
    return resposta == null ? resultados : await resposta!(enderecoDigitado);
  }
}

void main() {
  const sugestao = LocalizacaoSelecionada(
    ponto: LatLng(-21.2, -50.4),
    nome: 'Local de teste',
    endereco: 'Rua de teste',
  );
  Future<void> montarBarra(
    WidgetTester tester,
    _EnderecoServiceFalso service, {
    TextEditingController? controller,
    double escala = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(escala)),
            child: BarraPesquisaEndereco(
              controller: controller,
              enderecoService: service,
              onSelecionado: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  for (final tipo in TipoFalhaEndereco.values) {
    testWidgets('mapa diferencia $tipo de vazio e permite tentar novamente', (
      tester,
    ) async {
      final service = _EnderecoServiceFalso([sugestao]);
      service.resposta = (_) async {
        if (service.quantidadeBuscas == 1) throw FalhaBuscaEndereco(tipo);
        return [sugestao];
      };
      await montarBarra(tester, service);
      await tester.enterText(find.byType(TextField), 'rua teste');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text(FalhaBuscaEndereco(tipo).mensagem), findsOneWidget);
      expect(find.textContaining('Nenhum endereço encontrado'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(service.quantidadeBuscas, 2);
      expect(find.text('Local de teste'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'rua teste',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mudar consulta remove sugestoes antigas antes do debounce', (
    tester,
  ) async {
    final service = _EnderecoServiceFalso([sugestao]);
    await montarBarra(tester, service);
    await tester.enterText(find.byType(TextField), 'primeira rua');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Local de teste'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'outra rua');
    await tester.pump();
    expect(find.text('Local de teste'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  testWidgets('erro atrasado nao substitui resposta de consulta mais recente', (
    tester,
  ) async {
    final antiga = Completer<List<LocalizacaoSelecionada>>();
    final service = _EnderecoServiceFalso([])
      ..resposta = (texto) =>
          texto == 'antiga' ? antiga.future : Future.value([sugestao]);
    await montarBarra(tester, service);
    await tester.enterText(find.byType(TextField), 'antiga');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'nova rua');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    antiga.completeError(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    await tester.pumpAndSettle();
    expect(find.text('Local de teste'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('apagar pelo controller invalida carregamento e erro atrasado', (
    tester,
  ) async {
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    final service = _EnderecoServiceFalso([])
      ..resposta = (_) => pendente.future;
    final controller = TextEditingController();
    await montarBarra(tester, service, controller: controller);
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    controller.clear();
    await tester.pump();
    pendente.completeError(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('sair com consulta pendente nao gera setState apos dispose', (
    tester,
  ) async {
    final pendente = Completer<List<LocalizacaoSelecionada>>();
    final service = _EnderecoServiceFalso([])
      ..resposta = (_) => pendente.future;
    await montarBarra(tester, service);
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
    pendente.completeError(const FalhaBuscaEndereco(TipoFalhaEndereco.conexao));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('aviso longo cabe em 320 pixels com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _EnderecoServiceFalso([])
      ..resposta = (_) async =>
          throw const FalhaBuscaEndereco(TipoFalhaEndereco.respostaInvalida);
    await montarBarra(tester, service, escala: 1.8);
    await tester.enterText(find.byType(TextField), 'rua teste');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pesquisa enquanto digita e permite selecionar', (tester) async {
    const local = LocalizacaoSelecionada(
      ponto: LatLng(-21.2, -50.4),
      nome: 'Shopping Praça Nova Araçatuba',
      endereco: 'Av. Carlos Pereira da Silva, Araçatuba, SP',
    );

    final service = _EnderecoServiceFalso([local]);
    final controller = TextEditingController();

    LocalizacaoSelecionada? selecionado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraPesquisaEndereco(
            controller: controller,
            enderecoService: service,
            onSelecionado: (resultado) {
              selecionado = resultado;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'shopping praça nova');

    await tester.pump(const Duration(milliseconds: 499));

    expect(service.quantidadeBuscas, 0);

    await tester.pump(const Duration(milliseconds: 1));

    await tester.pumpAndSettle();

    expect(service.quantidadeBuscas, 1);

    await tester.tap(find.text('Shopping Praça Nova Araçatuba'));

    await tester.pump();

    expect(selecionado, same(local));

    expect(controller.text, local.descricaoCompleta);

    await tester.enterText(find.byType(TextField), 'unisalesiano');

    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpAndSettle();

    expect(service.quantidadeBuscas, 2);

    controller.dispose();
  });

  testWidgets('avisa quando nenhum endereço é encontrado', (tester) async {
    final service = _EnderecoServiceFalso([]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraPesquisaEndereco(
            enderecoService: service,
            onSelecionado: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'lugar inexistente');

    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpAndSettle();

    expect(find.textContaining('Nenhum endereço encontrado'), findsOneWidget);
  });

  testWidgets('não pesquisa com menos de três caracteres', (tester) async {
    final service = _EnderecoServiceFalso([]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarraPesquisaEndereco(
            enderecoService: service,
            onSelecionado: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ab');

    await tester.pump(const Duration(milliseconds: 600));

    expect(service.quantidadeBuscas, 0);
  });
}
