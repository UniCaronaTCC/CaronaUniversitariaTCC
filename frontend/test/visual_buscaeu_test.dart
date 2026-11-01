import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/caronas_publicadas.dart';
import 'package:uni_carona/home/detalhes_carona.dart';
import 'package:uni_carona/home/minhas_caronas.dart';
import 'package:uni_carona/home/ofertar_carona.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/solicitacao_enviada.dart';
import 'package:uni_carona/models/solicitacao_recebida.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/mensagem_service.dart';
import 'package:uni_carona/services/solicitacao_service.dart';

// Dados fictícios: a conferência de layout não acessa contas nem o servidor.
const _nomeLongo = 'Marina de Albuquerque Santos Oliveira';
const _destino = 'Centro Universitário — Campus Jardim das Universidades';
const _embarque = 'Praça Central, Avenida dos Estudantes, 1250';
const _capturas = String.fromEnvironment('PREVIA_VISUAL');

Carona _carona({bool longa = false}) => Carona(
  id: 1,
  origem: longa ? _embarque : 'Praça Central, Centro',
  destino: longa ? _destino : 'UniSalesiano, Araçatuba',
  dataInicio: DateTime(2090, 11, 4),
  horario: '18:30:00',
  vagas: 3,
  valor: 8,
  recorrente: true,
  diasSemana: const ['SEG', 'QUA', 'SEX'],
  motorista: longa ? _nomeLongo : 'Marina Santos',
  veiculoModelo: 'Onix',
  veiculoCor: 'Branco',
  veiculoPlaca: '***1D23',
);

Map<String, dynamic> _perfil(bool longo) => {
  'id': 9,
  'nome': longo ? _nomeLongo : 'Marina Santos',
  'email': 'marina.exemplo@universidade.edu.br',
  'instituicao': longo ? _destino : 'UniSalesiano',
  'campus': 'Araçatuba',
  'tipoPerfil': 'AMBOS',
  'statusVerificacao': 'APROVADO',
  'statusVerificacaoCnh': 'APROVADA',
  'cnhCategoria': 'AB',
  'cnhValidade': '2099-10-07',
  'veiculo': {'modelo': 'Onix', 'cor': 'Branco', 'placa': '***1D23'},
};

Widget _tela(String nome, bool longa) => switch (nome) {
  'suas-caronas' => CaronasPublicadasTela(
    carregarPublicadas: () async => {
      'sucesso': true,
      'dados': [_carona(longa: longa)],
    },
  ),
  'solicitacoes' => MinhasCaronasTela(
    carregarRecebidas: () async => {
      'sucesso': true,
      'dados': [
        SolicitacaoRecebida(
          id: 1,
          status: 'PENDENTE',
          localEmbarque: longa ? _embarque : 'Praça Central',
          embarqueLatitude: -21.2,
          embarqueLongitude: -50.4,
          passageiro: longa ? _nomeLongo : 'Lucas Almeida',
          idCarona: 1,
          destino: longa ? _destino : 'UniSalesiano, Araçatuba',
          dataInicio: DateTime(2090, 11, 4),
          horario: '18:30:00',
        ),
      ],
    },
    carregarEnviadas: () async => {
      'sucesso': true,
      'dados': <SolicitacaoEnviada>[],
    },
  ),
  'detalhes' => DetalhesCaronaTela(carona: _carona(longa: longa)),
  'ofertar' => OfertarCaronaTela(
    carregarPerfil: () async => {'sucesso': true, 'dados': _perfil(longa)},
  ),
  'perfil' => PerfilTela(
    carregarPerfil: () async => {'sucesso': true, 'dados': _perfil(longa)},
    carregarAvaliacoes: (_, _) async => {
      'sucesso': true,
      'dados': {
        'media': 4.8,
        'total': 15,
        'pagina': 1,
        'totalPaginas': 1,
        'avaliacoes': [],
      },
    },
  ),
  _ => throw ArgumentError(nome),
};

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = 'token-de-teste';
  });
  tearDown(() async {
    SolicitacaoService.pararContadorSolicitacoesPendentes();
    await MensagemService.pararContadorMensagensNaoLidas();
    AuthService.usuarioLogado = null;
    AuthService.tokenUsuarioLogado = null;
  });

  for (final estreita in [false, true]) {
    for (final nome in [
      'suas-caronas',
      'solicitacoes',
      'detalhes',
      'ofertar',
      'perfil',
    ]) {
      testWidgets('$nome: ${estreita ? '320px e fonte 180%' : '390px'}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(estreita ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader('Inter')
              ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Regular.ttf'))
              ..addFont(rootBundle.load('assets/fontes/Inter_18pt-Bold.ttf')))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
              rootBundle.load(
                'packages/cupertino_icons/assets/CupertinoIcons.ttf',
              ),
            ))
            .load();
        final captura = GlobalKey();
        final erros = <String>[];
        final anterior = FlutterError.onError;
        FlutterError.onError = (detalhes) {
          erros.add(detalhes.toString());
          anterior?.call(detalhes);
        };
        addTearDown(() => FlutterError.onError = anterior);
        await http.runWithClient(() async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: captura,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(estreita ? 1.8 : 1)),
                  child: child!,
                ),
                home: _tela(nome, estreita),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: erros.join('\n'));
          if (_capturas.isNotEmpty && !estreita) {
            await tester.runAsync(() async {
              final boundary =
                  captura.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final imagem = await boundary.toImage(pixelRatio: 2);
              final bytes = await imagem.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(_capturas).create(recursive: true);
              await File(
                '$_capturas/$nome.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              imagem.dispose();
            });
          }
          // Percorre o corpo inteiro para também conferir os controles abaixo
          // da primeira dobra, incluindo capacidade, recorrência e conta.
          final rolagem = find.byType(Scrollable).first;
          for (var i = 0; i < 8; i++) {
            await tester.drag(rolagem, const Offset(0, -400));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (nome == 'solicitacoes') {
            await tester.tap(find.text('Enviadas'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          SolicitacaoService.pararContadorSolicitacoesPendentes();
          await MensagemService.pararContadorMensagensNaoLidas();
        }, () => MockClient((_) async => http.Response('{"dados":[]}', 200)));
      });
    }
  }
}
