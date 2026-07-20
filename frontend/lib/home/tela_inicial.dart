import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do app
import '../widgets/botao_acao_home.dart'; // Importa o botão grande usado na tela inicial
import '../widgets/card_carona_disponivel.dart'; // Importa o card de carona disponível
import '../widgets/card_destino_home.dart'; // Importa o card de destino da tela inicial
import '../widgets/barra_navegacao_home.dart'; // Importa a barra inferior da tela inicial
import 'buscar_carona.dart'; // Importa a tela responsável pela busca de caronas
import 'ofertar_carona.dart'; // Importa a tela responsável por ofertar caronas

class TelaInicial extends StatelessWidget {
  // Cria a tela inicial do app
  final String nomeUsuario; // Guarda o nome do usuário logado

  const TelaInicial({
    super.key,
    required this.nomeUsuario, // Obriga receber o nome do usuário ao abrir a tela
  });

  @override
  Widget build(BuildContext context) {
    // Tudo que aparece visualmente na tela fica aqui
    return Scaffold(
      backgroundColor: AppColors.background, // Define a cor de fundo da tela
      // Adiciona a barra inferior de navegação
      bottomNavigationBar: const BarraNavegacaoHome(),

      body: SafeArea(
        child: SingleChildScrollView(
          // Permite rolar a tela se o conteúdo passar do tamanho disponível
          child: Padding(
            padding: const EdgeInsets.all(24), // Espaçamento interno da tela

            child: Column(
              // Organiza os elementos um embaixo do outro
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Alinha os itens à esquerda

              children: [
                Text.rich(
                  // Permite colocar estilos diferentes no mesmo texto
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Olá, ',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      TextSpan(
                        text: nomeUsuario.isNotEmpty ? nomeUsuario : 'usuário',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  maxLines: 2, // Permite no máximo duas linhas
                  overflow: TextOverflow
                      .ellipsis, // Corta nomes muito grandes com reticências
                ),

                const SizedBox(height: 8),

                const Text(
                  'Para onde você vai hoje?',
                  style: TextStyle(fontSize: 20, color: AppColors.text),
                ),

                const SizedBox(height: 36),

                // Card que mostra o destino principal
                const CardDestinoHome(
                  destino: 'AVENIDA UNISALESIANO, NÚMERO 2026',
                ),

                const SizedBox(height: 36),

                // Botão que abre a tela de busca de caronas
                BotaoAcaoHome(
                  texto: 'BUSCAR',
                  icone: Icons.directions_car_outlined,

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BuscarCaronaTela(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Botão que abre a tela de oferta de carona
                BotaoAcaoHome(
                  texto: 'OFERTAR',
                  icone: Icons.groups_outlined,

                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OfertarCaronaTela(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 36),

                // Linha com o título da seção e o botão para visualizar todas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Lista completa de caronas ainda será criada',
                            ),
                          ),
                        );
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

                const SizedBox(height: 12),

                // Card temporário de exemplo
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
