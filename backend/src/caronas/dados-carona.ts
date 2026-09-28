import { Carona } from './carona.entity';

export interface DadosPontoEmbarque {
  nome: string | null;
  endereco: string;
  latitude: number;
  longitude: number;
  ordem: number;
}

export interface DadosCriacaoCarona {
  idUsuario: number;

  origem: string;
  origemCidade: string | null;
  origemLatitude: number;
  origemLongitude: number;

  destino: string;
  destinoCidade: string | null;
  destinoLatitude: number;
  destinoLongitude: number;

  dataInicio: string;
  dataFim: string | null;
  horario: string;
  vagas: number;
  valor: number;
  recorrente: boolean;
  diasSemana: string[] | null;
  observacoes?: string;

  pontosEmbarque: DadosPontoEmbarque[];
}

export interface DadosPosicaoAtualCarona {
  latitude: number;
  longitude: number;
  direcao: number | null;
  precisao: number;
}

export function aplicarDadosCarona(
  carona: Carona,
  dados: DadosCriacaoCarona,
): void {
  const possuiRecorrencia = dados.recorrente === true;

  carona.origem = dados.origem;
  carona.origemCidade = dados.origemCidade;
  carona.origemLatitude = dados.origemLatitude;
  carona.origemLongitude = dados.origemLongitude;

  carona.destino = dados.destino;
  carona.destinoCidade = dados.destinoCidade;
  carona.destinoLatitude = dados.destinoLatitude;
  carona.destinoLongitude = dados.destinoLongitude;

  carona.dataInicio = dados.dataInicio;

  carona.dataFim = possuiRecorrencia ? dados.dataFim : null;

  carona.horario = dados.horario;
  carona.vagas = dados.vagas;
  carona.valor = dados.valor;

  carona.recorrente = possuiRecorrencia;

  carona.diasSemana = possuiRecorrencia ? dados.diasSemana : null;

  carona.observacoes = dados.observacoes?.trim() || null;
}
