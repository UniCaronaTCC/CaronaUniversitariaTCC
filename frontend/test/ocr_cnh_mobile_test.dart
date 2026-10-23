import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/services/ocr_cnh_mobile.dart';

Map<String, dynamic> retornoNativo({bool vertical = false}) {
  Map<String, dynamic> item(String texto) => {
    'text': texto,
    'rect': {
      'left': 10,
      'top': 10,
      'right': vertical ? 20 : 80,
      'bottom': vertical ? 80 : 20,
    },
    'points': [],
    'recognizedLanguages': [],
    'symbols': [],
  };
  return {
    'text': 'NOME CPF VALIDADE',
    'blocks': [
      {
        ...item('NOME CPF VALIDADE'),
        'lines': [
          {
            ...item('NOME CPF VALIDADE'),
            'elements': [item('NOME'), item('CPF'), item('VALIDADE')],
          },
        ],
      },
    ],
  };
}

Future<Uint8List> fotoSintetica() async {
  final gravador = ui.PictureRecorder();
  ui.Canvas(gravador).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  final desenho = gravador.endRecording();
  final imagem = await desenho.toImage(1000, 800);
  try {
    return (await imagem.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    imagem.dispose();
    desenho.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('google_mlkit_text_recognizer');
  final arquivos = <String>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    arquivos.clear();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });
  test(
    'usa coordenadas do ML Kit, tenta rotação e apaga arquivo temporário',
    () async {
      var chamadas = 0, fechamentos = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            if (call.method == 'vision#closeTextRecognizer') {
              fechamentos++;
              return null;
            }
            chamadas++;
            final path = (call.arguments as Map)['imageData']['path'] as String;
            arquivos.add(path);
            expect(await File(path).exists(), true);
            final codec = await ui.instantiateImageCodec(
              await File(path).readAsBytes(),
            );
            final imagem = (await codec.getNextFrame()).image;
            expect(imagem.width, chamadas == 1 ? 1000 : 800);
            expect(imagem.height, chamadas == 1 ? 800 : 1000);
            imagem.dispose();
            codec.dispose();
            return chamadas == 1 ? {'text': '', 'blocks': []} : retornoNativo();
          });
      final original = await fotoSintetica();
      final copia = Uint8List.fromList(original);
      final resultado = await lerCnh(original);
      expect(resultado['largura'], 800);
      expect(resultado['altura'], 1000);
      expect(resultado['linhas'][0]['palavras'][0]['texto'], 'NOME');
      expect(chamadas, 2);
      expect(fechamentos, 1);
      expect(original, copia);
      expect(await File(arquivos.first).exists(), false);
    },
  );
  test('erro nativo fecha leitor e remove foto temporária', () async {
    var fechamentos = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          if (call.method == 'vision#closeTextRecognizer') {
            fechamentos++;
            return null;
          }
          arquivos.add((call.arguments as Map)['imageData']['path'] as String);
          throw PlatformException(code: 'leitura_falhou');
        });
    await expectLater(
      lerCnh(await fotoSintetica()),
      throwsA(isA<PlatformException>()),
    );
    expect(fechamentos, 1);
    expect(await File(arquivos.single).exists(), false);
  });
  test('continua girando quando os rótulos foram lidos de lado', () async {
    var chamadas = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
          if (call.method == 'vision#closeTextRecognizer') return null;
          chamadas++;
          return retornoNativo(vertical: chamadas == 1);
        });
    final resultado = await lerCnh(await fotoSintetica());
    expect(chamadas, 2);
    expect(resultado['largura'], 800);
    expect(resultado['altura'], 1000);
    final palavra = resultado['linhas'][0]['palavras'][0];
    expect(
      palavra['x1'] - palavra['x0'],
      greaterThan(palavra['y1'] - palavra['y0']),
    );
  });
}
