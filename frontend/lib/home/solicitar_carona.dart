import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/botao_acao_home.dart';

class SolicitarCaronaTela extends StatefulWidget {
  const SolicitarCaronaTela({super.key});

  @override
  State<SolicitarCaronaTela> createState() => _SolicitarCaronaTelaState();
}

class _SolicitarCaronaTelaState extends State<SolicitarCaronaTela> {
  final TextEditingController origemController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final TextEditingController horarioController = TextEditingController();
  final TextEditingController observacaoController = TextEditingController();

  void solicitarCarona() {
    if (origemController.text.isEmpty ||
        destinoController.text.isEmpty ||
        horarioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha origem, destino e horário'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicitação de carona criada com sucesso'),
      ),
    );
  }

  @override
  void dispose() {
    origemController.dispose();
    destinoController.dispose();
    horarioController.dispose();
    observacaoController.dispose();
    super.dispose();
  }

  Widget campoTexto({
    required String label,
    required IconData icone,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone, color: AppColors.primary),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('Solicitar carona'),
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
                'Solicitar carona',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Informe os dados da sua viagem',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 32),

              campoTexto(
                label: 'Origem',
                icone: Icons.my_location,
                controller: origemController,
              ),

              const SizedBox(height: 16),

              campoTexto(
                label: 'Destino',
                icone: Icons.location_on_outlined,
                controller: destinoController,
              ),

              const SizedBox(height: 16),

              campoTexto(
                label: 'Horário desejado',
                icone: Icons.access_time,
                controller: horarioController,
              ),

              const SizedBox(height: 16),

              campoTexto(
                label: 'Observações',
                icone: Icons.notes,
                controller: observacaoController,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              BotaoAcaoHome(
                texto: 'SOLICITAR CARONA',
                icone: Icons.directions_car_outlined,
                onPressed: solicitarCarona,
              ),
            ],
          ),
        ),
      ),
    );
  }
}