import 'dart:typed_data';
import 'package:flutter/material.dart';

class FotoCnh extends StatelessWidget {
  final String titulo;
  final Uint8List? bytes;
  final bool habilitada;
  final VoidCallback onFotografar;

  const FotoCnh({
    super.key,
    required this.titulo,
    this.bytes,
    required this.habilitada,
    required this.onFotografar,
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
        ],
      ),
    );
  }
}
