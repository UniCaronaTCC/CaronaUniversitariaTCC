import 'package:flutter/material.dart';

class MolduraCameraCnh extends StatelessWidget {
  final Rect area;
  const MolduraCameraCnh({super.key, required this.area});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _PintorMoldura(area)));
}

class _PintorMoldura extends CustomPainter {
  final Rect area;
  _PintorMoldura(this.area);

  @override
  void paint(Canvas canvas, Size size) {
    final quadro = Rect.fromLTRB(
      area.left * size.width,
      area.top * size.height,
      area.right * size.width,
      area.bottom * size.height,
    );
    final mascara = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(quadro);
    canvas.drawPath(mascara, Paint()..color = Colors.black54);
    canvas.drawRect(
      quadro,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_PintorMoldura oldDelegate) => oldDelegate.area != area;
}
