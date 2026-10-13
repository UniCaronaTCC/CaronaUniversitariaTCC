import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

// Coordenadas normalizadas na prévia inteira, sem esticar nem cortar a câmera.
ui.Rect molduraCnh(ui.Size previa) {
  const proporcao = 1.58;
  final largura = math.min(previa.width * .86, previa.height * .80 * proporcao);
  final altura = largura / proporcao;
  return ui.Rect.fromCenter(
    center: const ui.Offset(.5, .5),
    width: largura / previa.width,
    height: altura / previa.height,
  );
}

ui.Rect areaFotoCnh(ui.Size foto, double proporcaoPrevia, ui.Rect moldura) {
  // Prévia e JPEG podem ter proporções diferentes. Relaciona os recortes
  // centrais do mesmo sensor, com uma margem de 3% para as bordas da CNH.
  final largura = math.min(foto.width, foto.height * proporcaoPrevia);
  final altura = largura / proporcaoPrevia;
  final x = (foto.width - largura) / 2;
  final y = (foto.height - altura) / 2;
  return ui.Rect.fromLTRB(
    x + (moldura.left - .03).clamp(0, 1) * largura,
    y + (moldura.top - .03).clamp(0, 1) * altura,
    x + (moldura.right + .03).clamp(0, 1) * largura,
    y + (moldura.bottom + .03).clamp(0, 1) * altura,
  );
}

Future<Uint8List> recortarFotoGuiada(
  Uint8List bytes,
  double proporcaoPrevia,
  ui.Rect moldura,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  ui.Image? foto;
  try {
    foto = (await codec.getNextFrame()).image;
    if (foto.width <= foto.height) {
      throw const FormatException(
        'A foto saiu na vertical. Gire o celular e tente novamente.',
      );
    }
    final origem = areaFotoCnh(
      ui.Size(foto.width.toDouble(), foto.height.toDouble()),
      proporcaoPrevia,
      moldura,
    );
    if (origem.width < 600 || origem.height < 400) {
      throw const FormatException(
        'A resolução ficou pequena. Aproxime a câmera e tente novamente.',
      );
    }
    final escala = math.min(1.0, 1600 / origem.width);
    final destino = ui.Size(
      (origem.width * escala).floorToDouble(),
      (origem.height * escala).floorToDouble(),
    );
    final gravador = ui.PictureRecorder();
    ui.Canvas(
      gravador,
    ).drawImageRect(foto, origem, ui.Offset.zero & destino, ui.Paint());
    final desenho = gravador.endRecording();
    ui.Image? recorte;
    try {
      recorte = await desenho.toImage(
        destino.width.toInt(),
        destino.height.toInt(),
      );
      final dados = await recorte.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null) {
        throw const FormatException('Não foi possível preparar a foto.');
      }
      final resultado = dados.buffer.asUint8List();
      if (resultado.length > 5 * 1024 * 1024) {
        resultado.fillRange(0, resultado.length, 0);
        throw const FormatException(
          'A foto ficou muito grande. Tente novamente.',
        );
      }
      return resultado;
    } finally {
      recorte?.dispose();
      desenho.dispose();
    }
  } finally {
    foto?.dispose();
    codec.dispose();
  }
}
