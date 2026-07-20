import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class AuthCampoTexto extends StatelessWidget {
  // Campo de texto visual para login/cadastro
  final String hint; // Texto que aparece dentro do campo
  final IconData icone; // Ícone do campo
  final TextEditingController controller; // Controla o texto digitado
  final bool obscureText; // Define se o texto será escondido
  final TextInputType? keyboardType; // Define o tipo de teclado

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
  // Botão principal para login/cadastro
  final String texto; // Texto do botão
  final VoidCallback? onPressed; // Função executada ao clicar

  const AuthBotaoPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Ocupa toda a largura disponível
      height: 54, // Altura do botão
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary, // Texto roxo
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Botão arredondado
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
  // Card visual reutilizável para telas de autenticação
  final List<Widget>
  children; // Lista de elementos que vão aparecer dentro do card

  const AuthCard({
    super.key,
    required this.children, // Obriga informar o conteúdo do card
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      // Recorta tudo dentro das bordas arredondadas
      borderRadius: BorderRadius.circular(30), // Arredonda o card inteiro
      child: Container(
        // Container principal do card
        width: double.infinity, // Ocupa toda a largura disponível
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // Cria um degradê no fundo do card
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary, // Roxo principal
              Color.lerp(
                AppColors.primary,
                Colors.black,
                0.16,
              )!, // Roxo um pouco mais escuro
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35), // Cor da sombra
              blurRadius: 18, // Suaviza a sombra
              offset: const Offset(0, 8), // Move a sombra para baixo
            ),
          ],
        ),
        child: Stack(
          // Permite colocar as ondas atrás do conteúdo
          children: [
            Positioned(
              // Posiciona a decoração na parte inferior
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                // Desenha as ondas decorativas
                size: const Size(double.infinity, 120),
                painter: _AuthOndasPainter(),
              ),
            ),

            Padding(
              // Espaçamento interno do conteúdo
              padding: const EdgeInsets.fromLTRB(
                28,
                36,
                28,
                76,
              ), // Aumenta o espaço de baixo para o conteúdo não ficar em cima da onda
              child: Column(
                // Organiza o conteúdo dentro do card
                mainAxisSize: MainAxisSize.min, // Usa só o espaço necessário
                children: children, // Mostra os widgets recebidos
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthOndasPainter extends CustomPainter {
  // Desenha as ondas decorativas do card
  @override
  void paint(Canvas canvas, Size size) {
    final primeiraOnda =
        Paint() // Configura a primeira onda
          ..color = Colors.white.withAlpha(42)
          ..style = PaintingStyle.fill;

    final segundaOnda =
        Paint() // Configura a segunda onda
          ..color = Colors.white.withAlpha(26)
          ..style = PaintingStyle.fill;

    final pathPrimeira = Path(); // Caminho da primeira onda
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

    final pathSegunda = Path(); // Caminho da segunda onda
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

    canvas.drawPath(pathSegunda, segundaOnda); // Desenha a onda de trás
    canvas.drawPath(pathPrimeira, primeiraOnda); // Desenha a onda da frente
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Não precisa redesenhar toda hora
  }
}
