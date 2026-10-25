import 'package:flutter/material.dart';
import '../services/verificacao_cnh_service.dart';

class DadosCnhExtraidos extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? carregar;
  const DadosCnhExtraidos({super.key, this.carregar});

  @override
  State<DadosCnhExtraidos> createState() => _DadosCnhExtraidosState();
}

class _DadosCnhExtraidosState extends State<DadosCnhExtraidos> {
  late final Future<Map<String, dynamic>> dados =
      widget.carregar?.call() ??
      const VerificacaoCnhService().buscarDadosExtraidos();

  String campo(Map<String, dynamic> dados, String chave) {
    final valor = dados[chave]?.toString().trim();
    return valor == null || valor.isEmpty
        ? 'Não identificado nesta leitura'
        : valor;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: dados,
    builder: (context, resultado) {
      if (resultado.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      if (resultado.hasError ||
          resultado.data == null ||
          resultado.data!.isEmpty) {
        return const Text(
          'Os dados adicionais da CNH não estão disponíveis agora.',
        );
      }
      final valores = resultado.data!;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dados lidos da CNH',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Nome: ${campo(valores, 'nome')}'),
            Text('Registro da CNH: ${campo(valores, 'registro')}'),
          ],
        ),
      );
    },
  );
}
