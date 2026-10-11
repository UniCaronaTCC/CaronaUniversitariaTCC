import 'dart:typed_data';
import 'dart:ui' as ui;
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

  Future<void> confirmar() async {
    if (imagem == null || salvando) return;
    setState(() => salvando = true);
    try {
      final foto = imagem!;
      final origem = Rect.fromLTRB(
        (selecao.left * foto.width).floorToDouble(),
        (selecao.top * foto.height).floorToDouble(),
        (selecao.right * foto.width).ceilToDouble(),
        (selecao.bottom * foto.height).ceilToDouble(),
      );
      if (origem.width < 600 || origem.height < 400) {
        setState(
          () => erro = 'O recorte ficou pequeno. Tire uma foto mais próxima',
        );
        return;
      }
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawImageRect(foto, origem, Offset.zero & origem.size, Paint());
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
      appBar: AppBar(title: const Text('Recortar CNH')),
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
                    Size(foto.width.toDouble(), foto.height.toDouble()),
                    Size(limites.maxWidth - 48, limites.maxHeight - 48),
                  ).destination;
                  return Center(
                    child: SizedBox(
                      width: tamanho.width,
                      height: tamanho.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RawImage(image: foto, fit: BoxFit.fill),
                          ),
                          Positioned.fromRect(
                            rect: Rect.fromLTRB(
                              selecao.left * tamanho.width,
                              selecao.top * tamanho.height,
                              selecao.right * tamanho.width,
                              selecao.bottom * tamanho.height,
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
                                  22,
                              top:
                                  ((canto < 2 ? selecao.top : selecao.bottom) *
                                      tamanho.height) -
                                  22,
                              child: Semantics(
                                label: 'Canto ${canto + 1} do recorte',
                                child: GestureDetector(
                                  key: ValueKey('canto-$canto'),
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
