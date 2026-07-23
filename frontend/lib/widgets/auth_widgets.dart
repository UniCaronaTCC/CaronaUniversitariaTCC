import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class AuthCampoTexto extends StatelessWidget {
  final String hint;
  final IconData icone;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  const AuthCampoTexto({
    super.key,
    required this.hint,
    required this.icone,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.text, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45),
        prefixIcon: Icon(icone, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class AuthBotaoPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const AuthBotaoPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  final List<Widget> children;

  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, Colors.black, 0.16)!,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 120),
                painter: _AuthOndasPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 76),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthOndasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final primeiraOnda = Paint()
      ..color = Colors.white.withAlpha(42)
      ..style = PaintingStyle.fill;

    final segundaOnda = Paint()
      ..color = Colors.white.withAlpha(26)
      ..style = PaintingStyle.fill;

    final pathPrimeira = Path();
    pathPrimeira.moveTo(0, size.height * 0.45);
    pathPrimeira.cubicTo(
      size.width * 0.25,
      size.height * 0.10,
      size.width * 0.55,
      size.height * 0.90,
      size.width,
      size.height * 0.35,
    );
    pathPrimeira.lineTo(size.width, size.height);
    pathPrimeira.lineTo(0, size.height);
    pathPrimeira.close();

    final pathSegunda = Path();
    pathSegunda.moveTo(0, size.height * 0.70);
    pathSegunda.cubicTo(
      size.width * 0.35,
      size.height * 0.35,
      size.width * 0.65,
      size.height * 1.05,
      size.width,
      size.height * 0.58,
    );
    pathSegunda.lineTo(size.width, size.height);
    pathSegunda.lineTo(0, size.height);
    pathSegunda.close();

    canvas.drawPath(pathSegunda, segundaOnda);
    canvas.drawPath(pathPrimeira, primeiraOnda);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
