import { BadRequestException } from '@nestjs/common';
import type { DadosCriacaoCarona } from './caronas.service';
import { DIAS_SEMANA, validarData } from './datas-recorrencia';
type DadosCaronaRecebidos = Record<string, unknown> | undefined;

export class ValidacaoCarona {
  validarDadosCarona(
    body: DadosCaronaRecebidos,
    idUsuario: number,
  ): DadosCriacaoCarona {
    const dados = body ?? {};

    const origem = dados.origem?.toString().trim() ?? '';
    const destino = dados.destino?.toString().trim() ?? '';
    const dataInicio = dados.dataInicio?.toString().trim() ?? '';
    const horario = dados.horario?.toString().trim() ?? '';

    if (!origem || !destino || !dataInicio || !horario) {
      throw new BadRequestException(
        'Origem, destino, data e horário são obrigatórios',
      );
    }

    if (origem.length > 255 || destino.length > 255) {
      throw new BadRequestException('Origem ou destino muito longo');
    }

    const vagas = Number(dados.vagas);
    const valor = Number(dados.valor);

    if (!Number.isInteger(vagas) || vagas <= 0 || vagas > 4) {
      throw new BadRequestException('Quantidade de vagas inválida');
    }

    if (!Number.isFinite(valor) || valor < 0) {
      throw new BadRequestException('Valor da carona inválido');
    }

    validarData(dataInicio);
    const dataFim = this.textoOpcional(dados.dataFim);
    if (dataFim) {
      validarData(dataFim);
      if (dataFim < dataInicio)
        throw new BadRequestException(
          'A data final deve ser igual ou posterior à inicial',
        );
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d:[0-5]\d$/.test(horario)) {
      throw new BadRequestException('Horário inválido');
    }
    const recorrente = dados.recorrente === true;

    const diasSemana = Array.isArray(dados.diasSemana)
      ? dados.diasSemana.map((dia: unknown) => dia?.toString() ?? '')
      : null;

    if (recorrente && (!Array.isArray(diasSemana) || diasSemana.length === 0)) {
      throw new BadRequestException('Selecione pelo menos um dia da semana');
    }
    if (recorrente && diasSemana?.some((dia) => !DIAS_SEMANA.includes(dia))) {
      throw new BadRequestException('Dia da semana inválido');
    }

    const pontosEmbarque = this.validarPontosEmbarque(dados.pontosEmbarque);

    return {
      idUsuario,

      origem,

      origemCidade: this.textoOpcional(dados.origemCidade, 100),

      origemLatitude: this.validarCoordenada(
        dados.origemLatitude,
        -90,
        90,
        'Latitude da origem',
      ),

      origemLongitude: this.validarCoordenada(
        dados.origemLongitude,
        -180,
        180,
        'Longitude da origem',
      ),

      destino,

      destinoCidade: this.textoOpcional(dados.destinoCidade, 100),

      destinoLatitude: this.validarCoordenada(
        dados.destinoLatitude,
        -90,
        90,
        'Latitude do destino',
      ),

      destinoLongitude: this.validarCoordenada(
        dados.destinoLongitude,
        -180,
        180,
        'Longitude do destino',
      ),

      dataInicio,

      dataFim: this.textoOpcional(dados.dataFim),

      horario,
      vagas,
      valor,
      recorrente,
      diasSemana: recorrente ? [...new Set(diasSemana)] : null,

      observacoes: this.textoOpcional(dados.observacoes) ?? undefined,

      pontosEmbarque,
    };
  }

  private validarPontosEmbarque(valor: unknown) {
    if (valor == null) {
      return [];
    }

    if (!Array.isArray(valor)) {
      throw new BadRequestException('Pontos de embarque inválidos');
    }

    return valor.map((item, indice) => {
      if (typeof item !== 'object' || item === null) {
        throw new BadRequestException(
          `Ponto de embarque ${indice + 1} inválido`,
        );
      }

      const ponto = item as Record<string, unknown>;

      const endereco = ponto.endereco?.toString().trim() ?? '';

      if (!endereco) {
        throw new BadRequestException(
          `Endereço do ponto de embarque ${indice + 1} é obrigatório`,
        );
      }

      if (endereco.length > 255) {
        throw new BadRequestException(
          `Endereço do ponto de embarque ${indice + 1} muito longo`,
        );
      }

      return {
        nome: this.textoOpcional(ponto.nome, 100),

        endereco,

        latitude: this.validarCoordenada(
          ponto.latitude,
          -90,
          90,
          `Latitude do ponto de embarque ${indice + 1}`,
        ),

        longitude: this.validarCoordenada(
          ponto.longitude,
          -180,
          180,
          `Longitude do ponto de embarque ${indice + 1}`,
        ),

        ordem: indice + 1,
      };
    });
  }

  private textoOpcional(valor: unknown, limite?: number): string | null {
    const texto = valor?.toString().trim() ?? '';

    if (limite != null && texto.length > limite) {
      throw new BadRequestException('Texto muito longo');
    }

    return texto || null;
  }

  private validarCoordenada(
    valorRecebido: unknown,
    minimo: number,
    maximo: number,
    nome: string,
  ): number {
    if (
      valorRecebido == null ||
      typeof valorRecebido === 'boolean' ||
      valorRecebido === ''
    ) {
      throw new BadRequestException(`${nome} obrigatória`);
    }
    const valor = Number(valorRecebido);

    if (!Number.isFinite(valor) || valor < minimo || valor > maximo) {
      throw new BadRequestException(`${nome} inválida`);
    }

    return valor;
  }
}
