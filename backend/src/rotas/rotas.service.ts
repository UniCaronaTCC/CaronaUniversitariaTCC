import {
  BadGatewayException,
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';

@Injectable()
export class RotasService {
  private readonly apiUrl =
    'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson';
  private readonly limiteTentativas = 2;

  async calcularRota(coordenadas: number[][]) {
    const apiKey = process.env.OPENROUTESERVICE_API_KEY;

    if (!apiKey) {
      throw new InternalServerErrorException(
        'OpenRouteService não configurado',
      );
    }

    if (coordenadas.length < 2) {
      throw new BadGatewayException('A rota precisa de origem e destino');
    }

    let ultimoErro: unknown;
    for (let tentativa = 1; tentativa <= this.limiteTentativas; tentativa++) {
      try {
        const resposta = await fetch(this.apiUrl, {
          method: 'POST',
          headers: {
            Authorization: apiKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            coordinates: coordenadas,
            // Permite ajustar locais amplos, como o centro de uma cidade,
            // para a rua dirigível mais próxima.
            radiuses: coordenadas.map(() => 1000),
          }),
          signal: AbortSignal.timeout(18000),
        });

        if (!resposta.ok) {
          const erroTemporario =
            resposta.status === 408 ||
            resposta.status === 429 ||
            resposta.status >= 500;
          if (!erroTemporario) {
            throw new ErroRotaPermanente(resposta.status);
          }
          throw new Error(`OpenRouteService: ${resposta.status}`);
        }

        const dados: any = await resposta.json();
        const rota = dados.features?.[0];
        if (!rota) throw new Error('Rota não encontrada');

        const pontos = rota.geometry.coordinates.map(
          ([longitude, latitude]: number[]) => [latitude, longitude],
        );
        return {
          pontos,
          distanciaMetros: rota.properties.summary.distance,
          duracaoSegundos: rota.properties.summary.duration,
        };
      } catch (erro) {
        ultimoErro = erro;
        if (erro instanceof ErroRotaPermanente) break;
        if (tentativa < this.limiteTentativas) {
          await new Promise((resolve) => setTimeout(resolve, 500));
        }
      }
    }

    console.error('Erro ao calcular rota:', ultimoErro);
    throw new BadGatewayException('Não foi possível calcular a rota');
  }
}

class ErroRotaPermanente extends Error {
  constructor(status: number) {
    super(`OpenRouteService: ${status}`);
  }
}
