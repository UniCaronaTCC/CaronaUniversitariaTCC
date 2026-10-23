import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<Map<String, dynamic>> lerCnh(Uint8List bytes) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError(
      'A leitura da CNH está disponível no Android e no iPhone.',
    );
  }
  final codec = await ui.instantiateImageCodec(bytes);
  final foto = (await codec.getNextFrame()).image;
  codec.dispose();
  final pasta = await Directory.systemTemp.createTemp('buscaeu_cnh_');
  final arquivo = File('${pasta.path}/frente.png');
  final leitor = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    if (foto.width * foto.height > 20000000 ||
        (foto.width < foto.height ? foto.width : foto.height) < 400 ||
        (foto.width > foto.height ? foto.width : foto.height) < 600) {
      throw const FormatException(
        'A foto precisa mostrar a CNH inteira com resolução suficiente.',
      );
    }
    Map<String, dynamic>? melhor;
    var melhorPontuacao = -1;
    // Cada resultado pertence a uma única orientação. Nunca misturamos campos.
    for (final giros in [0, 3, 1, 2]) {
      final largura = giros.isEven ? foto.width : foto.height;
      final altura = giros.isEven ? foto.height : foto.width;
      final gravador = ui.PictureRecorder();
      final canvas = ui.Canvas(gravador);
      if (giros == 1) {
        canvas.translate(largura.toDouble(), 0);
      }
      if (giros == 2) {
        canvas.translate(largura.toDouble(), altura.toDouble());
      }
      if (giros == 3) {
        canvas.translate(0, altura.toDouble());
      }
      canvas.rotate(giros * 3.141592653589793 / 2);
      canvas.drawImage(foto, ui.Offset.zero, ui.Paint());
      final desenho = gravador.endRecording();
      final orientada = await desenho.toImage(largura, altura);
      Uint8List? png;
      try {
        png = (await orientada.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        await arquivo.writeAsBytes(png, flush: true);
      } finally {
        orientada.dispose();
        desenho.dispose();
        png?.fillRange(0, png.length, 0);
      }
      final leitura = await leitor.processImage(
        InputImage.fromFilePath(arquivo.path),
      );
      final linhas = [
        for (final bloco in leitura.blocks)
          for (final linha in bloco.lines)
            {
              'palavras': [
                for (final p in linha.elements)
                  if (p.text.trim().isNotEmpty)
                    {
                      'texto': p.text,
                      'x0': p.boundingBox.left,
                      'y0': p.boundingBox.top,
                      'x1': p.boundingBox.right,
                      'y1': p.boundingBox.bottom,
                    },
              ],
            },
      ];
      final palavras = leitura.blocks
          .expand((b) => b.lines)
          .expand((l) => l.elements)
          // O ML Kit reconhece texto de lado, mas mantém suas caixas verticais.
          // Os campos do backend precisam de uma leitura na horizontal.
          .where((p) => p.boundingBox.width > p.boundingBox.height)
          .map((p) => p.text.toUpperCase().replaceAll(RegExp('[^A-Z]'), ''))
          .toList();
      final rotulos = [
        RegExp(r'^NOME$'),
        RegExp(r'^(D)?CPF$'),
        RegExp(r'^(B)?VALIDADE$'),
        RegExp(r'^(CATEGORIA|CAT|CATHAB)$'),
      ];
      final pontos = rotulos.where((r) => palavras.any(r.hasMatch)).length;
      if (pontos > melhorPontuacao) {
        melhorPontuacao = pontos;
        melhor = {'largura': largura, 'altura': altura, 'linhas': linhas};
      }
      if (pontos >= 3 && palavras.contains('NOME')) break;
    }
    return melhor!;
  } finally {
    foto.dispose();
    try {
      await leitor.close();
    } finally {
      if (await arquivo.exists()) await arquivo.delete();
      await pasta.delete();
    }
  }
}
