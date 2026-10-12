import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni_carona/home/recortar_cnh.dart';

void main() {
  Future<Uint8List> criarFoto(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final gravador = ui.PictureRecorder();
      final canvas = Canvas(gravador);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1000, 800),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 200, 200),
        Paint()..color = Colors.red,
      );
      final desenho = gravador.endRecording();
      final foto = await desenho.toImage(1000, 800);
      final bytes = (await foto.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      foto.dispose();
      desenho.dispose();
      return bytes;
    }))!;
  }

  Future<void> abrir(
    WidgetTester tester,
    Uint8List original,
    void Function(Uint8List?) concluir,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                concluir(await recortarCnh(context, original)),
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
  }

  Future<void> confirmar(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Usar recorte'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  for (final passos in [-1, 1, 2, 3, 4]) {
    testWidgets('rotação $passos preserva pixels, dimensões e original', (
      tester,
    ) async {
      final original = await criarFoto(tester);
      final copia = Uint8List.fromList(original);
      Uint8List? resultado;
      await abrir(tester, original, (bytes) => resultado = bytes);
      for (var i = 0; i < passos.abs(); i++) {
        await tester.tap(
          find.byKey(ValueKey(passos < 0 ? 'girar-esquerda' : 'girar-direita')),
        );
        await tester.pump();
      }
      final giros = passos % 4;
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        giros,
      );
      await confirmar(tester);
      expect(resultado, isNotNull);
      expect(original, copia);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(resultado!);
        final imagem = (await codec.getNextFrame()).image;
        expect(imagem.width, giros.isEven ? 1000 : 800);
        expect(imagem.height, giros.isEven ? 800 : 1000);
        final pixels = (await imagem.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final x = giros == 1 || giros == 2 ? imagem.width - 50 : 50;
        final y = giros == 2 || giros == 3 ? imagem.height - 50 : 50;
        final indice = (y * imagem.width + x) * 4;
        expect(pixels.getUint8(indice), Colors.red.r * 255);
        expect(pixels.getUint8(indice + 1), Colors.red.g * 255);
        expect(pixels.getUint8(indice + 2), Colors.red.b * 255);
        expect(pixels.getUint8(indice + 3), 255);
        imagem.dispose();
        codec.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('girar mantém a mesma área selecionada', (tester) async {
    final original = await criarFoto(tester);
    Uint8List? resultado;
    await abrir(tester, original, (bytes) => resultado = bytes);
    await tester.drag(
      find.byKey(const ValueKey('canto-0')),
      const Offset(30, 30),
    );
    await tester.pump();
    final tamanho = tester.getSize(find.byType(RawImage));
    final borda = tester.widget<Positioned>(
      find.byWidgetPredicate(
        (w) => w is Positioned && w.child is IgnorePointer,
      ),
    );
    final largura = 1000 - (borda.left! / tamanho.width * 1000).floor();
    final altura = 800 - (borda.top! / tamanho.height * 800).floor();
    await tester.tap(find.byKey(const ValueKey('girar-direita')));
    await tester.pump();
    await confirmar(tester);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(resultado!);
      final imagem = (await codec.getNextFrame()).image;
      expect(imagem.width, closeTo(altura, 1));
      expect(imagem.height, closeTo(largura, 1));
      imagem.dispose();
      codec.dispose();
    });
  });

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
