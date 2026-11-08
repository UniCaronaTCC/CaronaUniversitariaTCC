class Reputacao {
  final double media;
  final int total;

  const Reputacao({required this.media, required this.total})
    : assert(
        (total == 0 && media == 0) || (total > 0 && media >= 1 && media <= 5),
      );

  static Reputacao? tentarLer(Object? dados) {
    if (dados is! Map) return null;
    final media = double.tryParse(dados['media']?.toString() ?? '');
    final total = int.tryParse(dados['total']?.toString() ?? '');
    if (media == null ||
        !media.isFinite ||
        total == null ||
        total < 0 ||
        (total == 0 ? media != 0 : media < 1 || media > 5)) {
      return null;
    }
    return Reputacao(media: media, total: total);
  }

  String get mediaFormatada => media.toStringAsFixed(1).replaceAll('.', ',');
}
