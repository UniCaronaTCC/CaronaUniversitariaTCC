import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/recortar_cnh.dart';

void main() {
  testWidgets('recorte retorna apenas a área escolhida e preserva original', (
    tester,
  ) async {
    final original = (await tester.runAsync(() async {
      final gravador = ui.PictureRecorder();
      Canvas(gravador).drawRect(
        const Rect.fromLTWH(0, 0, 1000, 800),
        Paint()..color = Colors.white,
      );
      final desenho = gravador.endRecording();
      final foto = await desenho.toImage(1000, 800);
      final original = (await foto.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      foto.dispose();
      desenho.dispose();
      return original;
    }))!;
    Uint8List? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                resultado = await recortarCnh(context, original),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('canto-0')),
      const Offset(30, 30),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Usar recorte'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(resultado, isNotNull);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(resultado!);
      final recorte = (await codec.getNextFrame()).image;
      expect(recorte.width, lessThan(1000));
      expect(recorte.height, lessThan(800));
      expect(original.any((b) => b != 0), isTrue);
      recorte.dispose();
      codec.dispose();
    });
  });

  testWidgets('cancelar recorte não retorna imagem', (tester) async {
    Uint8List? resultado;
    var concluiu = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await recortarCnh(context, Uint8List(0));
              concluiu = true;
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(concluiu, isTrue);
    expect(resultado, isNull);
  });
}
