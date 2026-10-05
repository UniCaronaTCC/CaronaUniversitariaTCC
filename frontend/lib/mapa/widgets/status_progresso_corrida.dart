import 'package:flutter/material.dart';
import '../services/progresso_corrida.dart';

class StatusProgressoCorrida extends StatelessWidget {
  final ProgressoCorrida progresso;
  const StatusProgressoCorrida({super.key, required this.progresso});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progresso,
      builder: (_, _) {
        if (progresso.erro != null) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  progresso.erro!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                onPressed: progresso.sincronizar,
                tooltip: 'Sincronizar pontos',
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
        }
        final ponto = progresso.proximo;
        if (!progresso.carregado || ponto == null) {
          return const SizedBox.shrink();
        }
        return TextButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(
            progresso.salvando
                ? 'Salvando ponto...'
                : 'Marcar ponto ${ponto.ordem} como percorrido',
          ),
          onPressed: progresso.salvando
              ? null
              : () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Você passou pelo ponto ${ponto.ordem}?'),
                      content: const Text(
                        'Isso registra o percurso, não confirma o embarque de passageiros.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCELAR'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('CONFIRMAR'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true &&
                      context.mounted &&
                      progresso.proximo?.id == ponto.id) {
                    progresso.marcarProximo();
                  }
                },
        );
      },
    );
  }
}
