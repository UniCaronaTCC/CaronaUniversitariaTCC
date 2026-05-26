import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class AuthCampoTexto extends StatelessWidget { // Campo de texto visual para login/cadastro
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
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.black45,
        ),
        prefixIcon: Icon(
          icone,
          color: AppColors.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class AuthBotaoPrincipal extends StatelessWidget { // Botão principal para login/cadastro
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