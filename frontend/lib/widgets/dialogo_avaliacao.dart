import 'package:flutter/material.dart';

import '../config/app_colors.dart';

class DadosAvaliacao {
  final int nota;
  final String? comentario;

  const DadosAvaliacao({required this.nota, this.comentario});
}

Future<DadosAvaliacao?> mostrarDialogoAvaliacao(
  BuildContext context,
  String nome,
) async {
  var nota = 0;
  var comentario = '';

  final resultado = await showDialog<DadosAvaliacao>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, atualizarDialogo) => AlertDialog(
        title: Text('Avaliar $nome'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (indice) {
                  final valor = indice + 1;

                  return IconButton(
                    tooltip: '$valor ${valor == 1 ? 'estrela' : 'estrelas'}',
                    onPressed: () => atualizarDialogo(() => nota = valor),
                    icon: Icon(
                      valor <= nota ? Icons.star : Icons.star_border,
                      color: AppColors.primary,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (valor) => comentario = valor,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: nota == 0
                ? null
                : () {
                    final comentarioFinal = comentario.trim();
                    Navigator.pop(
                      context,
                      DadosAvaliacao(
                        nota: nota,
                        comentario: comentarioFinal.isEmpty
                            ? null
                            : comentarioFinal,
                      ),
                    );
                  },
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );

  return resultado;
}
