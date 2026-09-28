import 'package:flutter/material.dart';

class AvisoAtualizandoRota extends StatelessWidget {
  const AvisoAtualizandoRota({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Atualizando rota...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class AvisoErroRota extends StatelessWidget {
  final VoidCallback? onTentarNovamente;

  const AvisoErroRota({super.key, this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Não foi possível atualizar a rota.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: onTentarNovamente,
                child: const Text('TENTAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
