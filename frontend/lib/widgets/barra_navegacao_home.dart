import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class BarraNavegacaoHome extends StatelessWidget {
  // Cria a barra inferior da tela inicial
  final ValueChanged<int>? onTap;

  const BarraNavegacaoHome({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // Cria a barra inferior de navegação
      currentIndex: 0, // Define que o item "Início" está selecionado
      selectedItemColor: AppColors.primary, // Cor do item selecionado
      unselectedItemColor: Colors.black54, // Cor dos itens não selecionados
      type: BottomNavigationBarType.fixed, // Mantém todos os itens visíveis
      onTap: onTap,
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
          icon: Icon(Icons.directions_car_outlined),
          label: 'Caronas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }
}
