import 'package:flutter/material.dart'; // Importa os componentes visuais do Flutter
import '../config/app_colors.dart'; // Importa as cores principais do aplicativo
import '../widgets/botao_acao_home.dart'; // Importa o botão reutilizável da Home

class OfertarCaronaTela extends StatefulWidget { // Cria a tela usada para ofertar uma carona
  const OfertarCaronaTela({super.key});

  @override
  State<OfertarCaronaTela> createState() => _OfertarCaronaTelaState();
}

class _OfertarCaronaTelaState extends State<OfertarCaronaTela> {

  // Controllers responsáveis por guardar os textos digitados
  final TextEditingController origemController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController dataController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();
  final TextEditingController vagasController = TextEditingController();
  final TextEditingController valorController = TextEditingController();
  final TextEditingController observacoesController = TextEditingController();

  // Função executada quando o usuário clicar em ofertar
  void ofertarCarona() {

    // Verifica se os campos obrigatórios foram preenchidos
    if (origemController.text.isEmpty ||
        destinoController.text.isEmpty ||
        dataController.text.isEmpty ||
        horarioController.text.isEmpty ||
        vagasController.text.isEmpty ||
        valorController.text.isEmpty) {

      // Mostra uma mensagem caso algum campo obrigatório esteja vazio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios'),
        ),
      );

      return; // Encerra a função
    }

    // Mensagem temporária enquanto o backend ainda não está conectado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Oferta de carona criada com sucesso'),
      ),
    );
  }

  @override
  void dispose() { // Função executada quando a tela for fechada

    // Libera os controllers da memória
    origemController.dispose();
    destinoController.dispose();
    dataController.dispose();
    horarioController.dispose();
    vagasController.dispose();
    valorController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  // Cria um campo de texto reutilizável dentro desta tela
  Widget campoTexto({
    required String label,
    required IconData icone,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
        title: const Text('Ofertar carona'),
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
                'Ofertar carona',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Informe os dados da viagem',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 32),

              // Campo de origem
              campoTexto(
                label: 'Origem',
                icone: Icons.my_location,
                controller: origemController,
              ),

              const SizedBox(height: 16),

              // Campo de destino
              campoTexto(
                label: 'Destino',
                icone: Icons.location_on_outlined,
                controller: destinoController,
              ),

              const SizedBox(height: 16),

              // Campo de data
              campoTexto(
                label: 'Data',
                icone: Icons.calendar_today_outlined,
                controller: dataController,
              ),

              const SizedBox(height: 16),

              // Campo de horário
              campoTexto(
                label: 'Horário',
                icone: Icons.access_time,
                controller: horarioController,
              ),

              const SizedBox(height: 16),

              // Campo de quantidade de vagas
              campoTexto(
                label: 'Quantidade de vagas',
                icone: Icons.people_outline,
                controller: vagasController,
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),

              // Campo de valor da carona
              campoTexto(
                label: 'Valor por passageiro',
                icone: Icons.attach_money,
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),

              const SizedBox(height: 16),

              // Campo opcional de observações
              campoTexto(
                label: 'Observações',
                icone: Icons.notes,
                controller: observacoesController,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Botão responsável por criar a oferta
              BotaoAcaoHome(
                texto: 'OFERTAR CARONA',
                icone: Icons.groups_outlined,
                onPressed: ofertarCarona,
              ),
            ],
          ),
        ),
      ),
    );
  }
}