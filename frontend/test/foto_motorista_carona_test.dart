import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/widgets/avatar_usuario.dart';
import 'package:uni_carona/widgets/conteudo_detalhes_carona.dart';

import 'card_carona_home_test.dart' as cards;
import 'home_cards_test.dart' as dados;

class _ClienteFoto implements HttpClient {
  final int status;
  final List<int> bytes;
  final bool semConexao;
  final urls = <Uri>[];

  _ClienteFoto({
    this.status = 200,
    this.bytes = const [],
    this.semConexao = false,
  });

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    urls.add(url);
    if (semConexao) throw const SocketException('Sem conexao');
    return _RequisicaoFoto(_RespostaFoto(status, bytes));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RequisicaoFoto implements HttpClientRequest {
  final HttpClientResponse resposta;
  _RequisicaoFoto(this.resposta);

  @override
  Future<HttpClientResponse> close() async => resposta;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RespostaFoto extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> bytes;
  _RespostaFoto(this.statusCode, this.bytes);

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const url = 'https://imagens.exemplo.com/perfil.jpg';
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final foto in [
    null,
    '',
    '  ',
    12,
    false,
    <String, dynamic>{},
    ' $url ',
  ]) {
    test('modelo le a foto de usuario.fotoPerfil: $foto', () {
      final json = dados.dadosCarona(10);
      json['usuario'] = <String, dynamic>{
        ...(json['usuario'] as Map<String, dynamic>),
        'fotoPerfil': foto,
      };
      final carona = Carona.fromJson(json);
      expect(carona.fotoMotorista, foto == ' $url ' ? url : isNull);
      expect(carona.motorista, 'Henrique');
      expect(carona.idMotorista, 50);
      expect(carona.veiculoModelo, 'Onix');
    });
  }

  test('resposta antiga sem foto ou usuario continua compativel', () {
    final json = dados.dadosCarona(10);
    expect(Carona.fromJson(json).fotoMotorista, isNull);
    json.remove('usuario');
    expect(Carona.fromJson(json).fotoMotorista, isNull);
  });

  Future<void> usarCliente(
    _ClienteFoto cliente,
    Future<void> Function() executar,
  ) async {
    final anterior = debugNetworkImageHttpClientProvider;
    try {
      debugNetworkImageHttpClientProvider = () => cliente;
      await executar();
    } finally {
      debugNetworkImageHttpClientProvider = anterior;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

  for (final foto in [null, '', '  ']) {
    testWidgets('sem foto nao faz download e preserva a inicial: $foto', (
      tester,
    ) async {
      final cliente = _ClienteFoto();
      await usarCliente(cliente, () async {
        await cards.abrir(tester, cards.viagem(fotoMotorista: foto));
        await tester.pumpAndSettle();
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(avatar.foregroundImage, isNull);
        expect(find.text('H'), findsOneWidget);
        expect(cliente.urls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets(
    'foto valida e decodificada sem alterar tamanho nem toque no card',
    (tester) async {
      final cliente = _ClienteFoto(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
      await usarCliente(cliente, () async {
        var toques = 0;
        await cards.abrir(
          tester,
          cards.viagem(fotoMotorista: ' $url '),
          onTap: () => toques++,
        );
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect((avatar.foregroundImage! as NetworkImage).url, url);
        expect(tester.getSize(find.byType(CircleAvatar)), const Size(36, 36));
        await tester.runAsync(() async {
          final carregada = Completer<void>();
          final stream = avatar.foregroundImage!.resolve(
            const ImageConfiguration(),
          );
          final listener = ImageStreamListener((info, _) {
            expect(info.image.width, 1);
            expect(info.image.height, 1);
            info.dispose();
            carregada.complete();
          }, onError: carregada.completeError);
          stream.addListener(listener);
          try {
            await carregada.future.timeout(const Duration(seconds: 5));
          } finally {
            stream.removeListener(listener);
          }
        });
        await tester.pumpAndSettle();
        expect(cliente.urls, [Uri.parse(url)]);
        await tester.tap(find.text('Henrique'));
        expect(toques, 1);
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final falha in ['404', 'vazia', 'invalida', 'conexao']) {
    testWidgets('falha de foto $falha mantem fallback sem quebrar o card', (
      tester,
    ) async {
      final cliente = _ClienteFoto(
        status: falha == '404' ? 404 : 200,
        bytes: falha == 'invalida' ? [1, 2, 3] : [],
        semConexao: falha == 'conexao',
      );
      await usarCliente(cliente, () async {
        await cards.abrir(tester, cards.viagem(fotoMotorista: url));
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        await tester.runAsync(() async {
          final falhou = Completer<void>();
          final stream = avatar.foregroundImage!.resolve(
            const ImageConfiguration(),
          );
          final listener = ImageStreamListener((info, _) {
            info.dispose();
            falhou.completeError(StateError('Imagem invalida foi carregada'));
          }, onError: (_, _) => falhou.complete());
          stream.addListener(listener);
          try {
            await falhou.future.timeout(const Duration(seconds: 5));
          } finally {
            stream.removeListener(listener);
          }
        });
        await tester.pumpAndSettle();
        expect(find.text('H'), findsOneWidget);
        expect(find.text('Henrique'), findsOneWidget);
        expect(tester.getSize(find.byType(CircleAvatar)), const Size(36, 36));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('atualizar o card troca a foto e remover volta para a inicial', (
    tester,
  ) async {
    await usarCliente(_ClienteFoto(status: 404), () async {
      for (final foto in [url, 'https://imagens.exemplo.com/nova.jpg', null]) {
        await cards.abrir(tester, cards.viagem(fotoMotorista: foto));
        await tester.pumpAndSettle();
        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect((avatar.foregroundImage as NetworkImage?)?.url, foto);
        expect(find.text('H'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  for (final explicita in [null, 'https://imagens.exemplo.com/chat.jpg']) {
    testWidgets(
      'detalhes preservam foto da carona e preferencia explicita: $explicita',
      (tester) async {
        await usarCliente(_ClienteFoto(status: 404), () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ConteudoDetalhesCarona(
                  carona: cards.viagem(fotoMotorista: url),
                  fotoMotorista: explicita,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final avatar = tester.widget<AvatarUsuario>(
            find.byType(AvatarUsuario),
          );
          expect(avatar.urlFoto, explicita ?? url);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }
}
