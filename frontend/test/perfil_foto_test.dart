import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uni_carona/config/app_theme.dart';
import 'package:uni_carona/home/perfil.dart';
import 'package:uni_carona/services/auth_service.dart';
import 'package:uni_carona/services/sessao_service.dart';
import 'package:uni_carona/widgets/aviso_app.dart';
import 'package:uni_carona/widgets/conteudo_perfil_buscaeu.dart';
import 'package:uni_carona/widgets/foto_perfil.dart';

const fotoAntiga = 'https://example.test/usuarios/1/perfil?v=1';
const perfil = {
  'id': 1,
  'nome': 'Joao',
  'fotoPerfil': fotoAntiga,
  'statusVerificacaoCnh': 'APROVADA',
  'cnhCategoria': 'AB',
  'cnhValidade': '2099-05-01',
  'veiculo': {'id': 7, 'modelo': 'Onix', 'cor': 'Branco', 'placa': 'ABC1D23'},
};

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.usuarioLogado = Map<String, dynamic>.from(perfil);
    AuthService.tokenUsuarioLogado = null;
  });
  tearDown(() {
    AuthService.tokenUsuarioLogado = null;
    AuthService.usuarioLogado = null;
  });

  Future<void> abrir(
    WidgetTester tester, {
    Map<String, dynamic> dados = perfil,
    SelecionarFotoPerfil? galeria,
    SelecionarFotoPerfil? camera,
    EnviarFotoPerfil? enviar,
    RemoverFotoPerfil? remover,
    bool usarPlugin = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PerfilTela(
          carregarPerfil: () async => {'sucesso': true, 'dados': dados},
          carregarAvaliacoes: (_, _) async => {
            'sucesso': true,
            'dados': {'media': 0, 'total': 0},
          },
          selecionarFoto: usarPlugin ? null : galeria ?? () async => null,
          capturarFoto: usarPlugin ? null : camera ?? () async => null,
          enviarFoto: enviar ?? (_) async => {'sucesso': false},
          removerFoto: remover ?? (_) async => {'sucesso': false},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pumpAndSettle();
  }

  Future<void> escolher(
    WidgetTester tester,
    String opcao, {
    bool aguardar = true,
  }) async {
    await menu(tester);
    await tester.tap(find.text(opcao));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (aguardar) await tester.pumpAndSettle();
  }

  ConteudoPerfilBuscaEu conteudo(WidgetTester tester) =>
      tester.widget(find.byType(ConteudoPerfilBuscaEu));

  testWidgets('menu oferece camera, galeria e remocao quando existe foto', (
    tester,
  ) async {
    await abrir(tester);
    await menu(tester);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
    expect(find.text('Remover foto'), findsOneWidget);
  });

  testWidgets('sem foto nao mostra remover e usa inicial', (tester) async {
    await abrir(tester, dados: {...perfil, 'fotoPerfil': null});
    expect(tester.widget<FotoPerfil>(find.byType(FotoPerfil)).urlFoto, isNull);
    expect(find.text('J'), findsOneWidget);
    await menu(tester);
    expect(find.text('Remover foto'), findsNothing);
  });

  for (final origem in ['Tirar foto', 'Escolher da galeria']) {
    testWidgets(
      '$origem configura o plugin nativo com origem, compressao e camera frontal',
      (tester) async {
        const canal = MethodChannel('plugins.flutter.io/image_picker');
        final chamadas = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(canal, (call) async {
              chamadas.add(call);
              return 'foto-plugin.jpg';
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(canal, null),
        );
        String? enviada;
        await abrir(
          tester,
          usarPlugin: true,
          enviar: (path) async {
            enviada = path;
            return {'sucesso': true, 'dados': perfil};
          },
        );
        await escolher(tester, origem);
        expect(enviada, 'foto-plugin.jpg');
        expect(chamadas, hasLength(1));
        expect(chamadas.single.method, 'pickImage');
        expect(
          chamadas.single.arguments,
          containsPair('source', origem == 'Tirar foto' ? 0 : 1),
        );
        expect(chamadas.single.arguments, containsPair('cameraDevice', 1));
        expect(chamadas.single.arguments, containsPair('maxWidth', 1024.0));
        expect(chamadas.single.arguments, containsPair('maxHeight', 1024.0));
        expect(chamadas.single.arguments, containsPair('imageQuality', 80));
      },
    );

    testWidgets('$origem envia somente a origem escolhida e preserva dados', (
      tester,
    ) async {
      var cameras = 0;
      var galerias = 0;
      String? enviada;
      final atualizado = {...perfil, 'fotoPerfil': 'https://example.test/nova'};
      await abrir(
        tester,
        camera: () async {
          cameras++;
          return XFile('camera.jpg');
        },
        galeria: () async {
          galerias++;
          return XFile('galeria.jpg');
        },
        enviar: (path) async {
          enviada = path;
          return {'sucesso': true, 'dados': atualizado};
        },
      );
      await escolher(tester, origem);
      expect(cameras, origem == 'Tirar foto' ? 1 : 0);
      expect(galerias, origem == 'Tirar foto' ? 0 : 1);
      expect(enviada, origem == 'Tirar foto' ? 'camera.jpg' : 'galeria.jpg');
      expect(conteudo(tester).usuario, atualizado);
      expect(
        tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
        TipoAviso.sucesso,
      );
    });

    testWidgets('cancelar $origem nao altera foto nem mostra erro', (
      tester,
    ) async {
      var chamadas = 0;
      await abrir(
        tester,
        enviar: (_) async {
          chamadas++;
          return {'sucesso': false};
        },
      );
      await escolher(tester, origem);
      expect(chamadas, 0);
      expect(conteudo(tester).usuario, perfil);
      expect(find.byType(AvisoApp), findsNothing);
    });

    testWidgets('permissao negada em $origem tem mensagem em portugues', (
      tester,
    ) async {
      Future<XFile?> negar() async => throw PlatformException(
        code: origem == 'Tirar foto'
            ? 'camera_access_denied'
            : 'photo_access_denied',
      );
      await abrir(tester, camera: negar, galeria: negar);
      await escolher(tester, origem);
      expect(find.textContaining('Permita o acesso'), findsOneWidget);
      expect(conteudo(tester).usuario, perfil);
      expect(conteudo(tester).enviandoFoto, isFalse);
    });
  }

  testWidgets('fechar menu nao chama camera galeria ou remocao', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      camera: () async {
        chamadas++;
        return null;
      },
      galeria: () async {
        chamadas++;
        return null;
      },
      remover: (_) async {
        chamadas++;
        return {'sucesso': false};
      },
    );
    await menu(tester);
    Navigator.of(tester.element(find.text('Tirar foto'))).pop();
    await tester.pumpAndSettle();
    expect(chamadas, 0);
    expect(conteudo(tester).usuario, perfil);
  });

  testWidgets('remocao exige confirmacao e cancelar preserva foto', (
    tester,
  ) async {
    var chamadas = 0;
    await abrir(
      tester,
      remover: (_) async {
        chamadas++;
        return {'sucesso': false};
      },
    );
    await escolher(tester, 'Remover foto');
    expect(find.text('Remover foto de perfil?'), findsOneWidget);
    expect(chamadas, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(chamadas, 0);
    expect(conteudo(tester).usuario, perfil);
    expect(find.byType(AvisoApp), findsNothing);
  });

  for (final parcial in [false, true]) {
    testWidgets(
      'remover foto atualiza avatar e preserva CNH e veiculo; parcial=$parcial',
      (tester) async {
        var chamadas = 0;
        await abrir(
          tester,
          remover: (atual) async {
            chamadas++;
            expect(atual, fotoAntiga);
            return {
              'sucesso': true,
              'dados': {...perfil, 'fotoPerfil': null},
              if (parcial)
                'aviso':
                    'Foto removida do perfil. Limpeza do armazenamento indisponivel.',
            };
          },
        );
        await escolher(tester, 'Remover foto');
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        expect(chamadas, 1);
        expect(conteudo(tester).usuario, {...perfil, 'fotoPerfil': null});
        expect(find.text('J'), findsOneWidget);
        expect(
          tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
          parcial ? TipoAviso.atencao : TipoAviso.sucesso,
        );
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await menu(tester);
        expect(find.text('Remover foto'), findsNothing);
      },
    );
  }

  for (final excecao in [false, true]) {
    testWidgets(
      'falha de remocao preserva foto e libera nova tentativa; excecao=$excecao',
      (tester) async {
        await abrir(
          tester,
          remover: (_) async {
            if (excecao) throw StateError('falha sintetica');
            return {'sucesso': false, 'mensagem': 'Servidor indisponivel'};
          },
        );
        await escolher(tester, 'Remover foto');
        await tester.tap(find.text('Remover'));
        await tester.pumpAndSettle();
        expect(conteudo(tester).usuario, perfil);
        expect(conteudo(tester).enviandoFoto, isFalse);
        expect(
          tester.widget<AvisoApp>(find.byType(AvisoApp)).tipo,
          TipoAviso.erro,
        );
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        await menu(tester);
        expect(find.text('Remover foto'), findsOneWidget);
      },
    );
  }

  testWidgets('nao abre outro seletor enquanto a camera esta aberta', (
    tester,
  ) async {
    final foto = Completer<XFile?>();
    var chamadas = 0;
    await abrir(
      tester,
      camera: () {
        chamadas++;
        return foto.future;
      },
    );
    await escolher(tester, 'Tirar foto', aguardar: false);
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pump();
    expect(find.text('Tirar foto'), findsNothing);
    expect(chamadas, 1);
    foto.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('nao envia foto selecionada depois de trocar de conta', (
    tester,
  ) async {
    final foto = Completer<XFile?>();
    var envios = 0;
    await abrir(
      tester,
      camera: () => foto.future,
      enviar: (_) async {
        envios++;
        return {'sucesso': false};
      },
    );
    await escolher(tester, 'Tirar foto', aguardar: false);
    AuthService.usuarioLogado = {'id': 99};
    foto.complete(XFile('foto-anterior.jpg'));
    await tester.pumpAndSettle();
    expect(envios, 0);
  });

  testWidgets('envio em andamento mostra indicador e impede outro menu', (
    tester,
  ) async {
    final resposta = Completer<Map<String, dynamic>>();
    var envios = 0;
    await abrir(
      tester,
      camera: () async => XFile('camera.jpg'),
      enviar: (_) {
        envios++;
        return resposta.future;
      },
    );
    await escolher(tester, 'Tirar foto', aguardar: false);
    expect(conteudo(tester).enviandoFoto, isTrue);
    expect(
      tester.widget<FotoPerfil>(find.byType(FotoPerfil)).carregando,
      isTrue,
    );
    await tester.tap(find.byTooltip('Alterar foto de perfil'));
    await tester.pump();
    expect(find.text('Tirar foto'), findsNothing);
    expect(envios, 1);
    resposta.complete({'sucesso': true, 'dados': perfil});
    await tester.pumpAndSettle();
    expect(conteudo(tester).enviandoFoto, isFalse);
  });

  testWidgets(
    'erro de plataforma no envio nao e confundido com falha de camera',
    (tester) async {
      await abrir(
        tester,
        camera: () async => XFile('camera.jpg'),
        enviar: (_) async => throw PlatformException(code: 'falha_gravacao'),
      );
      await escolher(tester, 'Tirar foto');
      expect(
        find.text('Não foi possível atualizar a foto. Tente novamente'),
        findsOneWidget,
      );
      expect(conteudo(tester).usuario, perfil);
    },
  );

  testWidgets('resultado tardio apos sair da tela nao usa widget descartado', (
    tester,
  ) async {
    final foto = Completer<XFile?>();
    var envios = 0;
    await abrir(
      tester,
      camera: () => foto.future,
      enviar: (_) async {
        envios++;
        return {'sucesso': false};
      },
    );
    await escolher(tester, 'Tirar foto', aguardar: false);
    await tester.pumpWidget(const MaterialApp(home: Text('Outra tela')));
    foto.complete(XFile('foto.jpg'));
    await tester.pumpAndSettle();
    expect(envios, 0);
    expect(tester.takeException(), isNull);
  });

  for (final tamanho in [const Size(320, 640), const Size(700, 360)]) {
    testWidgets('menu e confirmacao cabem com fonte ampliada: $tamanho', (
      tester,
    ) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester);
      await menu(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Remover foto'));
      await tester.tap(find.text('Remover foto'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('avatar mostra carregamento mesmo com foto anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FotoPerfil(
            nome: 'Joao',
            urlFoto: fotoAntiga,
            carregando: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test(
    'DELETE autenticado atualiza cache e persistencia e repassa aviso',
    () async {
      AuthService.tokenUsuarioLogado = 'token-foto';
      final semFoto = {...perfil, 'fotoPerfil': null};
      final resultado = await http.runWithClient(
        () => AuthService.removerFotoPerfil(fotoAntiga),
        () => MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/usuarios/perfil/foto');
          expect(request.headers['Authorization'], 'Bearer token-foto');
          expect(jsonDecode(request.body), {'fotoAtual': fotoAntiga});
          return http.Response(
            jsonEncode({'dados': semFoto, 'aviso': 'Limpeza parcial'}),
            200,
          );
        }),
      );
      expect(resultado['sucesso'], isTrue);
      expect(resultado['aviso'], 'Limpeza parcial');
      expect(AuthService.usuarioLogado, semFoto);
      expect((await SessaoService.carregar())!['usuario'], semFoto);
    },
  );

  for (final status in [400, 403, 404, 409, 429, 500]) {
    test('DELETE HTTP $status nao apaga foto local nem demais dados', () async {
      AuthService.tokenUsuarioLogado = 'token-foto';
      await SessaoService.salvar('token-foto', perfil);
      final resultado = await http.runWithClient(
        () => AuthService.removerFotoPerfil(fotoAntiga),
        () => MockClient(
          (_) async => http.Response('{"message":"Falha sintetica"}', status),
        ),
      );
      expect(resultado['sucesso'], isFalse);
      expect(AuthService.usuarioLogado, perfil);
      expect((await SessaoService.carregar())!['usuario'], perfil);
    });
  }

  for (final timeout in [false, true]) {
    test(
      'DELETE com falha de rede preserva sessao e foto; timeout=$timeout',
      () async {
        AuthService.tokenUsuarioLogado = 'token-foto';
        await SessaoService.salvar('token-foto', perfil);
        final resultado = await http.runWithClient(
          () => AuthService.removerFotoPerfil(fotoAntiga),
          () => MockClient((_) async {
            if (timeout) throw TimeoutException('sintetico');
            throw http.ClientException('sintetico');
          }),
        );
        expect(resultado['sucesso'], isFalse);
        expect(AuthService.usuarioLogado, perfil);
        expect(AuthService.tokenUsuarioLogado, 'token-foto');
        expect((await SessaoService.carregar())!['usuario'], perfil);
      },
    );
  }
}
