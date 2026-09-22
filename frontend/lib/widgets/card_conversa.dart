import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../models/conversa.dart';
import 'avatar_usuario.dart';

class CardConversa extends StatelessWidget {
  final Conversa conversa;
  final int idUsuarioAtual;
  final VoidCallback? onTap;

  const CardConversa({
    super.key,
    required this.conversa,
    required this.idUsuarioAtual,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nome = conversa.nomeOutroParticipante(idUsuarioAtual);
    final foto = conversa.fotoOutroParticipante(idUsuarioAtual);
    final ultimaMensagem = conversa.ultimaMensagem;
    final temMensagensNaoLidas = conversa.mensagensNaoLidas > 0;
    final corFundo = temMensagensNaoLidas
        ? const Color(0xFFFBF5FF)
        : conversa.encerrada
        ? const Color(0xFFF3F3F3)
        : Colors.white;
    final corBorda = temMensagensNaoLidas
        ? AppColors.primary
        : const Color(0xFFE1E1E1);

    return Material(
      color: corFundo,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: corBorda,
              width: temMensagensNaoLidas ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarUsuario(
                key: ValueKey('avatar-conversa-${conversa.id}'),
                nome: nome,
                urlFoto: foto,
                desativado: conversa.encerrada,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: temMensagensNaoLidas
                                  ? AppColors.primary
                                  : AppColors.text,
                              fontSize: 16,
                              fontWeight: temMensagensNaoLidas
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (ultimaMensagem != null)
                          Text(
                            _formatarData(ultimaMensagem.criadoEm),
                            style: TextStyle(
                              color: temMensagensNaoLidas
                                  ? AppColors.primary
                                  : Colors.black45,
                              fontSize: 12,
                              fontWeight: temMensagensNaoLidas
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ultimaMensagem?.conteudo ??
                                'Nenhuma mensagem ainda',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: temMensagensNaoLidas
                                  ? AppColors.text
                                  : Colors.black54,
                              fontSize: 14,
                              fontWeight: temMensagensNaoLidas
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (temMensagensNaoLidas) ...[
                          const SizedBox(width: 8),
                          Badge.count(
                            key: ValueKey('mensagens-nao-lidas-${conversa.id}'),
                            count: conversa.mensagensNaoLidas,
                            backgroundColor: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conversa.destino,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (conversa.encerrada)
                          const Text(
                            'Encerrada',
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final agora = DateTime.now();
    final mesmoDia =
        data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;

    if (mesmoDia) {
      return '${data.hour.toString().padLeft(2, '0')}:'
          '${data.minute.toString().padLeft(2, '0')}';
    }

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}';
  }
}
