import 'dart:typed_data';
import 'package:flutter/material.dart';

class FotoCnh extends StatelessWidget {
  final String titulo;
  final Uint8List? bytes;
  final bool habilitada;
  final VoidCallback onFotografar;
  final VoidCallback onEscolherGaleria;

  const FotoCnh({
    super.key,
    required this.titulo,
    this.bytes,
    required this.habilitada,
    required this.onFotografar,
    required this.onEscolherGaleria,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Apoie o documento em uma superfície plana. Enquadre os quatro '
            'cantos, sem cortar as bordas, com as letras na posição normal de '
            'leitura (não de lado ou de cabeça para baixo). Evite reflexos '
            'e confira a foto antes de enviar.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.6,
            child: bytes == null
                ? const ColoredBox(
                    color: Color(0xFFF4F4F4),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 48,
                      color: Colors.black38,
                    ),
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text('Foto inválida. Tire outra foto'),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: habilitada ? onFotografar : null,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(bytes == null ? 'Fotografar' : 'Refazer foto'),
          ),
          OutlinedButton.icon(
            onPressed: habilitada ? onEscolherGaleria : null,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Escolher da galeria'),
          ),
        ],
      ),
    );
  }
}
