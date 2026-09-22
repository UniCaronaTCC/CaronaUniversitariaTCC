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

        const dados: unknown = await resposta.json();
        const rota = this.extrairRota(dados);
        if (!rota) throw new Error('Rota não encontrada');

        const pontos = rota.coordenadas.map(([longitude, latitude]) => [
          latitude,
          longitude,
        ]);
        return {
          pontos,
          distanciaMetros: rota.distanciaMetros,
          duracaoSegundos: rota.duracaoSegundos,
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

  private extrairRota(dados: unknown): RotaOpenRouteService | null {
    if (!this.ehRegistro(dados) || !this.ehLista(dados.features)) {
      return null;
    }

    const rota = dados.features[0];
    if (!this.ehRegistro(rota)) {
      return null;
    }

    const geometria = rota.geometry;
    const propriedades = rota.properties;
    if (!this.ehRegistro(geometria) || !this.ehRegistro(propriedades)) {
      return null;
    }

    const resumo = propriedades.summary;
    const coordenadas = geometria.coordinates;
    if (
      !this.ehRegistro(resumo) ||
      !this.ehLista(coordenadas) ||
      !coordenadas.every((coordenada) => this.coordenadaValida(coordenada)) ||
      typeof resumo.distance !== 'number' ||
      typeof resumo.duration !== 'number'
    ) {
      return null;
    }

    return {
      coordenadas,
      distanciaMetros: resumo.distance,
      duracaoSegundos: resumo.duration,
    };
  }

  private coordenadaValida(valor: unknown): valor is [number, number] {
    return (
      Array.isArray(valor) &&
      valor.length >= 2 &&
      typeof valor[0] === 'number' &&
      Number.isFinite(valor[0]) &&
      typeof valor[1] === 'number' &&
      Number.isFinite(valor[1])
    );
  }

  private ehRegistro(valor: unknown): valor is Record<string, unknown> {
    return typeof valor === 'object' && valor !== null;
  }

  private ehLista(valor: unknown): valor is unknown[] {
    return Array.isArray(valor);
  }
}

interface RotaOpenRouteService {
  coordenadas: [number, number][];
  distanciaMetros: number;
  duracaoSegundos: number;
}

class ErroRotaPermanente extends Error {
  constructor(status: number) {
    super(`OpenRouteService: ${status}`);
  }
}
