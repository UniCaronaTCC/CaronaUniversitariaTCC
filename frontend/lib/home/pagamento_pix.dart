import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_colors.dart';
import '../models/pagamento_pix.dart';
import '../utils/formatador_moeda.dart';
import '../widgets/componentes_padrao.dart';

class PagamentoPixTela extends StatelessWidget {
  final PagamentoPix pagamento;

  const PagamentoPixTela({super.key, required this.pagamento});

  @override
  Widget build(BuildContext context) {
    final qrCode = _decodificarQrCode(pagamento.qrCodeBase64);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const BarraSuperiorPadrao(titulo: 'Pagamento Pix'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const Align(alignment: Alignment.centerLeft, child: _SeloSandbox()),
            const SizedBox(height: 24),
            const Text(
              'Valor da carona',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _formatarCentavos(pagamento.valorCentavos),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _StatusPix(pagamento: pagamento),
            if (pagamento.pixDisponivel) ...[
              const SizedBox(height: 28),
              if (qrCode != null) ...[
                Center(
                  child: SizedBox.square(
                    dimension: 240,
                    child: Image.memory(
                      qrCode,
                      key: const ValueKey('qr-code-pix'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Pix copia e cola',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SelectableText(
                pagamento.pixCopiaECola!,
                key: const ValueKey('codigo-pix'),
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copiarCodigo(context),
                  icon: const Icon(Icons.content_copy),
                  label: const Text('COPIAR CÓDIGO PIX'),
                ),
              ),
            ],
            if (pagamento.expiraEm != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Válido até ${_formatarDataHora(pagamento.expiraEm!)}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copiarCodigo(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: pagamento.pixCopiaECola!));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código Pix copiado')));
  }

  Uint8List? _decodificarQrCode(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return null;
    }

    try {
      final base64 = valor.contains(',') ? valor.split(',').last : valor;
      return base64Decode(base64);
    } catch (erro) {
      return null;
    }
  }

  String _formatarCentavos(int valorCentavos) {
    return formatarDoubleComoMoedaReal(valorCentavos / 100);
  }

  String _formatarDataHora(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/${doisDigitos(data.month)} '
        'às ${doisDigitos(data.hour)}:${doisDigitos(data.minute)}';
  }
}

class _SeloSandbox extends StatelessWidget {
  const _SeloSandbox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: const Color(0xFFFFB74D)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'AMBIENTE DE TESTE',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusPix extends StatelessWidget {
  final PagamentoPix pagamento;

  const _StatusPix({required this.pagamento});

  @override
  Widget build(BuildContext context) {
    final (icone, cor, titulo, descricao) = switch ((
      pagamento.statusCriacao,
      pagamento.status,
    )) {
      ('CONFIRMADA', 'PENDING') => (
        Icons.schedule,
        const Color(0xFF7A5600),
        'Aguardando pagamento',
        'Use o QR Code ou o código Pix para pagar.',
      ),
      ('CONFIRMADA', 'PAID') => (
        Icons.check_circle_outline,
        const Color(0xFF176B3A),
        'Pagamento confirmado',
        'O provedor confirmou o recebimento do Pix.',
      ),
      ('PREPARADA', _) => (
        Icons.sync,
        const Color(0xFF5E4A7D),
        'Preparando cobrança',
        'A tentativa foi registrada e ainda está sendo processada.',
      ),
      ('INCERTA', _) => (
        Icons.info_outline,
        const Color(0xFF7A5600),
        'Confirmação pendente',
        'Não gere outro pagamento enquanto esta tentativa é conferida.',
      ),
      _ => (
        Icons.info_outline,
        Colors.black54,
        'Status do Pix: ${pagamento.status ?? pagamento.statusCriacao}',
        'A situação será atualizada quando o provedor confirmar o pagamento.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: cor, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(descricao, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
