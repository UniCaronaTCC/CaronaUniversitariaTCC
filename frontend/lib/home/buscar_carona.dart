import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do aplicativo
import '../widgets/botao_acao_home.dart'; // Importa o botão reutilizável da tela inicial

class BuscarCaronaTela extends StatefulWidget { // Cria a tela usada para buscar caronas disponíveis
  const BuscarCaronaTela({super.key});

  @override
  State<BuscarCaronaTela> createState() => _BuscarCaronaTelaState();
}

class _BuscarCaronaTelaState extends State<BuscarCaronaTela> { // Controla os dados e mudanças da tela

  // Controllers responsáveis por controlar os textos digitados nos campos
  final TextEditingController origemController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();
  final TextEditingController observacaoController = TextEditingController();

  // Função executada quando o usuário clicar no botão
  void buscarCarona() {

    // Verifica se os campos obrigatórios foram preenchidos
    if (origemController.text.isEmpty ||
        destinoController.text.isEmpty ||
        horarioController.text.isEmpty) {

      // Mostra uma mensagem caso algum campo obrigatório esteja vazio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha origem, destino e horário'),
        ),
      );

      return; // Encerra a função
    }

    // Mensagem temporária enquanto a busca real ainda não está conectada ao backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Busca de caronas realizada'),
      ),
    );
  }

  @override
  void dispose() { // Função chamada quando a tela é fechada

    // Libera os controllers da memória
    origemController.dispose();
    destinoController.dispose();
    horarioController.dispose();
    observacaoController.dispose();

    super.dispose();
  }

  // Cria um campo de texto reutilizável dentro desta tela
  Widget campoTexto({
    required String label,
    required IconData icone,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icone,
          color: AppColors.primary,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // Tudo que aparece visualmente fica aqui
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Buscar carona'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                'Buscar carona',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Informe os dados da viagem desejada',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 32),

              // Campo de origem da viagem
              campoTexto(
                label: 'Origem',
                icone: Icons.my_location,
                controller: origemController,
              ),

              const SizedBox(height: 16),

              // Campo de destino da viagem
              campoTexto(
                label: 'Destino',
                icone: Icons.location_on_outlined,
                controller: destinoController,
              ),

              const SizedBox(height: 16),

              // Campo de horário desejado
              campoTexto(
                label: 'Horário desejado',
                icone: Icons.access_time,
                controller: horarioController,
              ),

              const SizedBox(height: 16),

              // Campo opcional para observações
              campoTexto(
                label: 'Observações',
                icone: Icons.notes,
                controller: observacaoController,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Botão responsável por iniciar a busca
              BotaoAcaoHome(
                texto: 'BUSCAR CARONA',
                icone: Icons.search,
                onPressed: buscarCarona,
              ),
            ],
          ),
        ),
      ),
    );
  }
}