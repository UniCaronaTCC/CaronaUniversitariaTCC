import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app
import '../widgets/botao_acao_home.dart'; // Importa o botão grande usado na tela inicial

class TelaInicial extends StatelessWidget { // Cria a tela inicial do app
  const TelaInicial({super.key}); // Construtor da tela inicial

  @override
  Widget build(BuildContext context) { // Tudo que aparece visualmente na tela fica aqui
    return Scaffold( // Estrutura base da tela
      backgroundColor: AppColors.background, // Define a cor de fundo da tela

      body: SafeArea(
        child: SingleChildScrollView( // Permite rolar a tela se o conteúdo passar do tamanho disponível
          child: Padding(
            padding: const EdgeInsets.all(24), // Espaçamento interno da tela
            child: Column( // Organiza os elementos um embaixo do outro
              crossAxisAlignment: CrossAxisAlignment.start, // Alinha os itens à esquerda
              children: [
                RichText( // Permite colocar estilos diferentes no mesmo texto
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Olá, ', // Primeira parte do título
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: 'usuário', // Nome do usuário em destaque
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8), // Espaço entre o título e o subtítulo

                const Text(
                  'Para onde você vai hoje?',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 36), // Cria um espaço antes do card de destino

                Container( // Card que mostra o destino principal
                  width: double.infinity, // Ocupa toda a largura disponível
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // Espaçamento interno do card
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26), // Fundo roxo bem claro
                    borderRadius: BorderRadius.circular(22), // Arredonda as bordas do card
                  ),
                  child: Row( // Organiza o ícone e os textos em linha
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

                      Container( // Linha divisória entre "IR PARA" e o endereço
                        width: 1,
                        height: 30,
                        color: Colors.black26,
                      ),

                      const SizedBox(width: 14), // Espaço depois da linha divisória

                      const Expanded( // Faz o endereço ocupar o espaço restante sem estourar a tela
                        child: Text(
                          'AVENIDA UNISALESIANO, NÚMERO 2026', // Endereço fixo inicial
                          overflow: TextOverflow.ellipsis, // Corta o texto com "..." se passar do espaço
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36), // Espaço antes dos botões principais

                BotaoAcaoHome( // Botão para solicitar uma carona
                  texto: 'SOLICITAR',
                  icone: Icons.directions_car_outlined,
                  onPressed: () {
                    print('Solicitar carona clicado');
                  },
                ),

                const SizedBox(height: 20), // Espaço entre os botões

                BotaoAcaoHome( // Botão para ofertar uma carona
                  texto: 'OFERTAR',
                  icone: Icons.groups_outlined,
                  onPressed: () {
                    print('Ofertar carona clicado');
                  },
                ),

                const SizedBox(height: 36), // Espaço antes da seção de caronas disponíveis

                Row( // Linha com o título e o botão "Ver todas"
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Coloca um item em cada lado
                  children: [
                    const Text(
                      'Caronas disponíveis',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    TextButton(
                      onPressed: () {
                        print('Ver todas clicado');
                      },
                      child: const Text(
                        'Ver todas',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12), // Espaço entre o título da seção e o card

                Container( // Card de uma carona disponível
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
                  child: Row( // Organiza ícone, informações e seta em linha
                    children: [
                      Container( // Círculo com ícone do carro
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

                      const Expanded( // Faz as informações ocuparem o espaço disponível
                        child: Column( // Organiza as informações em coluna
                          crossAxisAlignment: CrossAxisAlignment.start, // Alinha os textos à esquerda
                          children: [
                            Text(
                              'Araçatuba → UniSalesiano', // Rota da carona
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              'Hoje • Noite', // Data e período
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),

                            SizedBox(height: 8),

                            Text(
                              'Motorista: Henrique', // Nome do motorista
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),

                            SizedBox(height: 14),

                            Text(
                              'R\$ 6,00', // Valor da carona
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.chevron_right, // Seta para indicar que o card poderá abrir detalhes
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}