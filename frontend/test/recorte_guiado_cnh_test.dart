import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/services/recorte_guiado_cnh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('moldura mantém proporção e margem em diferentes prévias', () {
    for (final tamanho in [
      const ui.Size(1600, 900),
      const ui.Size(1200, 900),
    ]) {
      final quadro = molduraCnh(tamanho);
      expect(
        quadro.width * tamanho.width / (quadro.height * tamanho.height),
        closeTo(1.58, .001),
      );
      expect(quadro.left, greaterThan(0));
      expect(quadro.top, greaterThan(0));
      final area = areaFotoCnh(
        const ui.Size(2400, 1800),
        tamanho.aspectRatio,
        quadro,
      );
      expect(area.center.dx, closeTo(1200, .001));
      expect(area.center.dy, closeTo(900, .001));
      expect(area.left, greaterThanOrEqualTo(0));
      expect(area.right, lessThanOrEqualTo(2400));
      expect(area.bottom, lessThanOrEqualTo(1800));
    }
  });
  test('recorta imagem sintética sem esticar e limita resolução', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF00FF00), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2400, 1800);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    final quadro = molduraCnh(const ui.Size(1600, 900));
    final area = areaFotoCnh(const ui.Size(2400, 1800), 16 / 9, quadro);
    final resultado = await recortarFotoGuiada(bytes, 16 / 9, quadro);
    final codec = await ui.instantiateImageCodec(resultado);
    final recorte = (await codec.getNextFrame()).image;
    expect(recorte.width, 1600);
    expect(
      recorte.width / recorte.height,
      closeTo(area.width / area.height, .005),
    );
    final pixels = await recorte.toByteData();
    expect(pixels!.getUint8(1), 255);
    recorte.dispose();
    codec.dispose();
    image.dispose();
    picture.dispose();
  });
}
