import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

Future<Uint8List?> recortarCnh(BuildContext context, Uint8List bytes) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => RecortarCnhTela(bytes: bytes)),
    );

class RecortarCnhTela extends StatefulWidget {
  final Uint8List bytes;
  const RecortarCnhTela({super.key, required this.bytes});

  @override
  State<RecortarCnhTela> createState() => _RecortarCnhTelaState();
}

class _RecortarCnhTelaState extends State<RecortarCnhTela> {
  ui.Image? imagem;
  Rect selecao = const Rect.fromLTRB(0, 0, 1, 1);
  bool salvando = false;
  int giros = 0;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() => imagem = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => erro = 'Não foi possível abrir a foto');
    }
  }

  void girar(int passo) {
    if (imagem == null || salvando) return;
    setState(() {
      giros = (giros + passo) % 4;
      selecao = passo > 0
          ? Rect.fromLTRB(
              1 - selecao.bottom,
              selecao.left,
              1 - selecao.top,
              selecao.right,
            )
          : Rect.fromLTRB(
              selecao.top,
              1 - selecao.right,
              selecao.bottom,
              1 - selecao.left,
            );
      erro = null;
    });
  }

  Future<void> confirmar() async {
    if (imagem == null || salvando) return;
    setState(() => salvando = true);
    try {
      final foto = imagem!;
      final largura = giros.isEven ? foto.width : foto.height;
      final altura = giros.isEven ? foto.height : foto.width;
      final origem = Rect.fromLTRB(
        (selecao.left * largura).floorToDouble(),
        (selecao.top * altura).floorToDouble(),
        (selecao.right * largura).ceilToDouble(),
        (selecao.bottom * altura).ceilToDouble(),
      );
      if (math.max(origem.width, origem.height) < 600 ||
          math.min(origem.width, origem.height) < 400) {
        setState(
          () => erro = 'O recorte ficou pequeno. Tire uma foto mais próxima',
        );
        return;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(-origem.left, -origem.top);
      switch (giros) {
        case 1:
          canvas.translate(foto.height.toDouble(), 0);
          canvas.rotate(math.pi / 2);
        case 2:
          canvas.translate(foto.width.toDouble(), foto.height.toDouble());
          canvas.rotate(math.pi);
        case 3:
          canvas.translate(0, foto.width.toDouble());
          canvas.rotate(3 * math.pi / 2);
      }
      canvas.drawImage(foto, Offset.zero, Paint());
      final desenho = recorder.endRecording();
      final recorte = await desenho.toImage(
        origem.width.toInt(),
        origem.height.toInt(),
      );
      desenho.dispose();
      try {
        final dados = await recorte.toByteData(format: ui.ImageByteFormat.png);
        if (dados == null) throw StateError('Imagem vazia');
        final bytes = dados.buffer.asUint8List();
        if (!mounted) {
          bytes.fillRange(0, bytes.length, 0);
        } else if (bytes.length > 5 * 1024 * 1024) {
          bytes.fillRange(0, bytes.length, 0);
          setState(() => erro = 'O recorte excedeu 5 MB. Tente outra foto');
        } else {
          Navigator.pop(context, bytes);
        }
      } finally {
        recorte.dispose();
      }
    } catch (_) {
      if (mounted) {
        setState(() => erro = 'Não foi possível recortar. Tente novamente');
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  void dispose() {
    imagem?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !salvando,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Recortar CNH'),
        actions: [
          IconButton(
            key: const ValueKey('girar-esquerda'),
            tooltip: 'Girar para a esquerda',
            onPressed: imagem == null || salvando ? null : () => girar(-1),
            icon: const Icon(Icons.rotate_left),
          ),
          IconButton(
            key: const ValueKey('girar-direita'),
            tooltip: 'Girar para a direita',
            onPressed: imagem == null || salvando ? null : () => girar(1),
            icon: const Icon(Icons.rotate_right),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Arraste os quatro cantos para deixar somente a CNH. '
                'Mantenha todas as bordas e as letras na posição de leitura.',
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, limites) {
                  final foto = imagem;
                  if (foto == null) {
                    return Center(
                      child: erro == null
                          ? const CircularProgressIndicator()
                          : Text(erro!),
                    );
                  }
                  final tamanho = applyBoxFit(
                    BoxFit.contain,
                    Size(
                      (giros.isEven ? foto.width : foto.height).toDouble(),
                      (giros.isEven ? foto.height : foto.width).toDouble(),
                    ),
                    Size(limites.maxWidth - 48, limites.maxHeight - 48),
                  ).destination;
                  return Center(
                    child: SizedBox(
                      width: tamanho.width + 48,
                      height: tamanho.height + 48,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 24,
                            top: 24,
                            width: tamanho.width,
                            height: tamanho.height,
                            child: RotatedBox(
                              quarterTurns: giros,
                              child: RawImage(image: foto, fit: BoxFit.fill),
                            ),
                          ),
                          Positioned.fromRect(
                            rect: Rect.fromLTRB(
                              24 + selecao.left * tamanho.width,
                              24 + selecao.top * tamanho.height,
                              24 + selecao.right * tamanho.width,
                              24 + selecao.bottom * tamanho.height,
                            ),
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.orange,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          for (var canto = 0; canto < 4; canto++)
                            Positioned(
                              left:
                                  ((canto % 2 == 0
                                          ? selecao.left
                                          : selecao.right) *
                                      tamanho.width) -
                                  22 +
                                  24,
                              top:
                                  ((canto < 2 ? selecao.top : selecao.bottom) *
                                      tamanho.height) -
                                  22 +
                                  24,
                              child: Semantics(
                                label: 'Canto ${canto + 1} do recorte',
                                child: GestureDetector(
                                  key: ValueKey('canto-$canto'),
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: salvando
                                      ? null
                                      : (evento) {
                                          final dx =
                                              evento.delta.dx / tamanho.width;
                                          final dy =
                                              evento.delta.dy / tamanho.height;
                                          setState(
                                            () => selecao = Rect.fromLTRB(
                                              canto % 2 == 0
                                                  ? (selecao.left + dx).clamp(
                                                      0,
                                                      selecao.right - .1,
                                                    )
                                                  : selecao.left,
                                              canto < 2
                                                  ? (selecao.top + dy).clamp(
                                                      0,
                                                      selecao.bottom - .1,
                                                    )
                                                  : selecao.top,
                                              canto % 2 == 1
                                                  ? (selecao.right + dx).clamp(
                                                      selecao.left + .1,
                                                      1,
                                                    )
                                                  : selecao.right,
                                              canto >= 2
                                                  ? (selecao.bottom + dy).clamp(
                                                      selecao.top + .1,
                                                      1,
                                                    )
                                                  : selecao.bottom,
                                            ),
                                          );
                                        },
                                  child: const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.crop_free,
                                      color: Colors.orange,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (erro != null && imagem != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(erro!)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: imagem == null || salvando ? null : confirmar,
                child: Text(salvando ? 'Recortando...' : 'Usar recorte'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
