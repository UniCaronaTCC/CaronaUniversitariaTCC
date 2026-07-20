import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app

class CardCaronaDisponivel extends StatelessWidget {
  // Cria o card reutilizável de carona disponível
  final String origem; // Cidade ou local de saída da carona
  final String destino; // Cidade ou local de destino da carona
  final String periodo; // Informação de data, horário ou período da carona
  final String motorista; // Nome do motorista
  final String valor; // Valor da carona

  const CardCaronaDisponivel({
    super.key,
    required this.origem,
    required this.destino,
    required this.periodo,
    required this.motorista,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Card de uma carona disponível
      width: double.infinity, // Ocupa toda a largura disponível
      padding: const EdgeInsets.all(20), // Espaçamento interno do card
      decoration: BoxDecoration(
        color: Colors.white, // Cor de fundo do card
        borderRadius: BorderRadius.circular(22), // Arredonda as bordas
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20), // Cor da sombra
            blurRadius: 16, // Deixa a sombra mais suave
            offset: const Offset(0, 6), // Move a sombra um pouco para baixo
          ),
        ],
      ),
      child: Row(
        // Organiza ícone, informações e seta em linha
        children: [
          Container(
            // Círculo com ícone do carro
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26), // Fundo roxo claro
              shape: BoxShape.circle, // Deixa circular
            ),
            child: const Icon(
              Icons.directions_car_outlined, // Ícone do carro
              color: AppColors.primary,
              size: 32,
            ),
          ),

          const SizedBox(width: 18), // Espaço entre o ícone e as informações

          Expanded(
            // Faz as informações ocuparem o espaço disponível
            child: Column(
              // Organiza as informações em coluna
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Alinha os textos à esquerda
              children: [
                Text(
                  '$origem → $destino', // Mostra origem e destino da carona
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  periodo, // Mostra data, horário ou período
                  style: const TextStyle(color: Colors.black54, fontSize: 15),
                ),

                const SizedBox(height: 8),

                Text(
                  'Motorista: $motorista', // Mostra o nome do motorista
                  style: const TextStyle(color: Colors.black54, fontSize: 15),
                ),

                const SizedBox(height: 14),

                Text(
                  valor, // Mostra o valor da carona
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .chevron_right, // Seta para indicar que o card poderá abrir detalhes
            color: AppColors.primary,
            size: 32,
          ),
        ],
      ),
    );
  }
}
