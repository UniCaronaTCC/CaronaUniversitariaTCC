import {
  BadGatewayException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';

@Injectable()
export class RotasService {
  private readonly apiUrl =
    'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson';

  async calcularRota(coordenadas: number[][]) {
    const apiKey = process.env.OPENROUTESERVICE_API_KEY;

    if (!apiKey) {
      throw new InternalServerErrorException(
        'OpenRouteService não configurado',
      );
    }

    if (coordenadas.length < 2) {
      throw new BadGatewayException(
        'A rota precisa de origem e destino',
      );
    }

    try {
      const resposta = await fetch(this.apiUrl, {
        method: 'POST',
        headers: {
          Authorization: apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          coordinates: coordenadas,
        }),
      });

      if (!resposta.ok) {
        throw new Error(`OpenRouteService: ${resposta.status}`);
      }

      const dados: any = await resposta.json();
      const rota = dados.features?.[0];

      if (!rota) {
        throw new Error('Rota não encontrada');
      }

      const pontos = rota.geometry.coordinates.map(
        ([longitude, latitude]: number[]) => [
          latitude,
          longitude,
        ],
      );

      return {
        pontos,
        distanciaMetros: rota.properties.summary.distance,
        duracaoSegundos: rota.properties.summary.duration,
      };
    } catch (erro) {
      console.error('Erro ao calcular rota:', erro);

      throw new BadGatewayException(
        'Não foi possível calcular a rota',
      );
    }
  }
}