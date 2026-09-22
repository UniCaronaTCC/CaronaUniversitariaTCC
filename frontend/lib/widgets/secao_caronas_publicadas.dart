import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/carona.dart';
import 'card_carona_disponivel.dart';

class SecaoCaronasPublicadas extends StatelessWidget {
  final List<Carona> caronas;
  final bool carregando;
  final String? mensagemErro;
  final VoidCallback onTentarNovamente;
  final VoidCallback onVerTodas;
  final ValueChanged<Carona> onAbrirCarona;
  final ValueChanged<Carona> onEditarCarona;
  final ValueChanged<Carona> onCancelarCarona;

  const SecaoCaronasPublicadas({
    super.key,
    required this.caronas,
    required this.carregando,
    required this.mensagemErro,
    required this.onTentarNovamente,
    required this.onVerTodas,
    required this.onAbrirCarona,
    required this.onEditarCarona,
    required this.onCancelarCarona,
  });

  @override
  Widget build(BuildContext context) {
    final caronasVisiveis = caronas.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Suas próximas caronas',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!carregando && mensagemErro == null && caronas.isNotEmpty)
              TextButton(onPressed: onVerTodas, child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 12),
        if (carregando)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (mensagemErro != null)
          Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: Colors.black54),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagemErro!,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              IconButton(
                tooltip: 'Tentar novamente',
                onPressed: onTentarNovamente,
                icon: const Icon(Icons.refresh),
              ),
            ],
          )
        else
          ListView.separated(
            itemCount: caronasVisiveis.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final carona = caronasVisiveis[index];

              return CardCaronaDisponivel(
                carona: carona,
                onTap: () => onAbrirCarona(carona),
                acaoCabecalho: PopupMenuButton<_AcaoCaronaPublicada>(
                  key: ValueKey('menu-carona-${carona.id}'),
                  tooltip: 'Ações da carona',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (acao) {
                    if (acao == _AcaoCaronaPublicada.editar) {
                      onEditarCarona(carona);
                    } else {
                      onCancelarCarona(carona);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _AcaoCaronaPublicada.editar,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _AcaoCaronaPublicada.cancelar,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Cancelar carona'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

enum _AcaoCaronaPublicada { editar, cancelar }
