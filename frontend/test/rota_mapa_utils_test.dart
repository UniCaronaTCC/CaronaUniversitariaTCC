import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:uni_carona/mapa/utils/rota_mapa_utils.dart';
import 'package:uni_carona/models/carona.dart';
import 'package:uni_carona/models/ponto_embarque.dart';
import 'package:uni_carona/mapa/widgets/marcadores_percurso.dart';

void main() {
  Carona viagem(
    List<PontoEmbarque> pontos, {
    double? origemLatitude = -21.8,
    double? origemLongitude = -50.8,
  }) => Carona(
    id: 7,
    origem: 'Origem antiga',
    origemLatitude: origemLatitude,
    origemLongitude: origemLongitude,
    destino: 'Campus',
    destinoLatitude: -21,
    destinoLongitude: -50,
    pontosEmbarque: pontos,
    dataInicio: DateTime(2099),
    horario: '18:00:00',
    vagas: 3,
    valor: 5,
    recorrente: false,
    diasSemana: [],
    motorista: 'Motorista',
  );
  const primeiro = PontoEmbarque(
    id: 10,
    endereco: 'Rua A',
    latitude: -21.2,
    longitude: -50.2,
    ordem: 1,
  );
  const segundo = PontoEmbarque(
    id: 11,
    endereco: 'Rua B',
    latitude: -21.1,
    longitude: -50.1,
    ordem: 2,
  );

  test(
    'previa usa o encontro como inicio mesmo com origem antiga diferente',
    () {
      expect(paradasDaCarona(viagem([primeiro])), [
        const LatLng(-21.2, -50.2),
        const LatLng(-21, -50),
      ]);
    },
  );
  test('previa funciona sem coordenadas de origem quando ha encontros', () {
    expect(
      paradasDaCarona(
        viagem([primeiro], origemLatitude: null, origemLongitude: null),
      ),
      hasLength(2),
    );
  });
  test('ordena encontros sem duplicar o primeiro como origem', () {
    expect(paradasDaCarona(viagem([segundo, primeiro])), [
      const LatLng(-21.2, -50.2),
      const LatLng(-21.1, -50.1),
      const LatLng(-21, -50),
    ]);
  });
  test('legado sem pontos ainda utiliza a origem salva', () {
    expect(paradasDaCarona(viagem([]))!.first, const LatLng(-21.8, -50.8));
    expect(
      paradasDaCarona(viagem([], origemLatitude: null, origemLongitude: null)),
      isNull,
    );
  });
  test('marcadores da previa incluem cada encontro uma unica vez', () {
    final carona = viagem([primeiro, segundo]);
    final marcadores = MarcadoresPercurso(
      carona: carona,
      paradas: paradasDaCarona(carona)!,
      navegacao: false,
      mostrarMarcadorMotorista: false,
      localizacaoMotorista: null,
      direcaoMotorista: 0,
      embarquesConcluidos: {},
    ).construir();
    expect(marcadores.map((m) => m.point), [
      const LatLng(-21.2, -50.2),
      const LatLng(-21.1, -50.1),
      const LatLng(-21, -50),
    ]);
  });
  test(
    'GPS continua sendo inicio privado da navegacao e pula encontros concluidos',
    () {
      expect(
        paradasDaNavegacao(
          viagem([primeiro, segundo]),
          const LatLng(-21.5, -50.5),
          {10},
        ),
        [
          const LatLng(-21.5, -50.5),
          const LatLng(-21.1, -50.1),
          const LatLng(-21, -50),
        ],
      );
    },
  );
  test('navegação começa na posição atual do motorista', () {
    final carona = Carona(
      id: 1,
      origem: 'Origem cadastrada',
      origemLatitude: -21.3,
      origemLongitude: -50.5,
      destino: 'Destino',
      destinoLatitude: -21.1,
      destinoLongitude: -50.3,
      dataInicio: DateTime(2026, 9, 14),
      horario: '18:00:00',
      vagas: 2,
      valor: 5,
      recorrente: false,
      diasSemana: const [],
      motorista: 'Motorista',
    );
    const posicaoMotorista = LatLng(-21.2, -50.4);

    final paradas = paradasDaNavegacao(carona, posicaoMotorista, const {});

    expect(paradas, isNotNull);
    expect(paradas!.first, posicaoMotorista);
    expect(paradas.first, isNot(const LatLng(-21.3, -50.5)));
  });
}
