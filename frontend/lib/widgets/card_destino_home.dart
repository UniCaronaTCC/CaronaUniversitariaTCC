import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class CardDestinoHome extends StatelessWidget {
  // Cria o card de destino da tela inicial
  final String destino; // Texto do destino exibido no card
  final VoidCallback onTap; // Abre a tela de selecao do destino

  const CardDestinoHome({
    super.key,
    required this.destino, // Obriga informar o destino
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          // Card que mostra o destino principal
          width: double.infinity, // Ocupa toda a largura disponível
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            // Organiza o ícone e os textos em linha
            children: [
              const Icon(
                Icons.location_on_outlined, // Ícone de localização
                color: AppColors.primary,
                size: 30,
              ),

              const SizedBox(width: 12), // Espaço entre o ícone e o texto

              const Text(
                'IR PARA:', // Texto fixo do card
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(width: 14), // Espaço antes da linha divisória

              Container(
                // Linha divisória entre "IR PARA" e o endereço
                width: 1,
                height: 30,
                color: Colors.black26,
              ),

              const SizedBox(width: 14), // Espaço depois da linha divisória

              Expanded(
                // Faz o destino ocupar o espaço restante sem estourar a tela
                child: Text(
                  destino, // Mostra o destino recebido
                  overflow: TextOverflow
                      .ellipsis, // Corta o texto com "..." se passar do espaço
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
