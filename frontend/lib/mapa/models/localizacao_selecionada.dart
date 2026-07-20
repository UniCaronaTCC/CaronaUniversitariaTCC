import 'package:latlong2/latlong.dart'; // Importa o tipo LatLng para guardar latitude e longitude

class LocalizacaoSelecionada {
  // Representa uma localizacao escolhida no mapa
  final LatLng ponto; // Guarda latitude e longitude
  final String endereco; // Guarda o endereco estimado

  const LocalizacaoSelecionada({required this.ponto, required this.endereco});
}
