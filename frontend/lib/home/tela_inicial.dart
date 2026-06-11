import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app
import '../widgets/botao_acao_home.dart'; // Importa o botão grande usado na tela inicial
import '../widgets/card_carona_disponivel.dart'; // Importa o card de carona disponível
import '../widgets/card_destino_home.dart'; // Importa o card de destino da tela inicial
import '../widgets/barra_navegacao_home.dart'; // Importa a barra inferior da tela inicial

class TelaInicial extends StatelessWidget { // Cria a tela inicial do app
  final String nomeUsuario; // Guarda o nome do usuário logado

  const TelaInicial({
    super.key,
    required this.nomeUsuario, // Obriga receber o nome do usuário ao abrir a tela
  });

  @override
  Widget build(BuildContext context) { // Tudo que aparece visualmente na tela fica aqui
    return Scaffold(
      backgroundColor: AppColors.background, // Define a cor de fundo da tela
      bottomNavigationBar: const BarraNavegacaoHome(), // Adiciona a barra inferior de navegação

      body: SafeArea(
        child: SingleChildScrollView( // Permite rolar a tela se o conteúdo passar do tamanho disponível
          child: Padding(
            padding: const EdgeInsets.all(24), // Espaçamento interno da tela
            child: Column( // Organiza os elementos um embaixo do outro
              crossAxisAlignment: CrossAxisAlignment.start, // Alinha os itens à esquerda
              children: [
                Text.rich( // Permite colocar estilos diferentes no mesmo texto
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Olá, ', // Primeira parte do título
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: nomeUsuario.isNotEmpty ? nomeUsuario : 'usuário', // Mostra o nome real ou um texto padrão
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2, // Permite no máximo duas linhas
                  overflow: TextOverflow.ellipsis, // Se o nome for muito grande, corta com "..."
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

                const CardDestinoHome(
                  destino: 'AVENIDA UNISALESIANO, NÚMERO 2026',
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

                const CardCaronaDisponivel(
                  origem: 'Araçatuba',
                  destino: 'UniSalesiano',
                  periodo: 'Hoje • Noite',
                  motorista: 'Henrique',
                  valor: 'R\$ 6,00',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}