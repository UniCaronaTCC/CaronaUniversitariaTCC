import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class BarraNavegacaoHome extends StatelessWidget {
  // Cria a barra inferior da tela inicial
  const BarraNavegacaoHome({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // Cria a barra inferior de navegação
      currentIndex: 0, // Define que o item "Início" está selecionado
      selectedItemColor: AppColors.primary, // Cor do item selecionado
      unselectedItemColor: Colors.black54, // Cor dos itens não selecionados
      type: BottomNavigationBarType.fixed, // Mantém todos os itens visíveis
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Início',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Publicar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }
}
