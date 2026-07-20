import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Carona } from './carona.entity';

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
}

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,
  ) {}

  async criarCarona(dados: DadosCriacaoCarona): Promise<Carona> {
    const possuiRecorrencia = dados.recorrente === true;

    const novaCarona = this.caronasRepository.create({
      origem: dados.origem,
      origemCidade: dados.origemCidade,
      origemLatitude: dados.origemLatitude,
      origemLongitude: dados.origemLongitude,

      destino: dados.destino,
      destinoCidade: dados.destinoCidade,
      destinoLatitude: dados.destinoLatitude,
      destinoLongitude: dados.destinoLongitude,

      dataInicio: dados.dataInicio,
      dataFim: possuiRecorrencia ? dados.dataFim : null,
      horario: dados.horario,
      vagas: dados.vagas,
      valor: dados.valor,

      recorrente: possuiRecorrencia,
      diasSemana: possuiRecorrencia
          ? dados.diasSemana
          : null,

      observacoes: dados.observacoes?.trim() || null,
      status: 'ATIVA',

      usuario: {
        idUsuario: dados.idUsuario,
      },
    });

    return this.caronasRepository.save(novaCarona);
  }

  // Lista somente ofertas ativas e que ainda podem acontecer.
  async listarCaronas(): Promise<Carona[]> {
    return this.caronasRepository
        .createQueryBuilder('carona')

        // Carrega somente identificacao e nome do motorista.
        .leftJoinAndSelect('carona.usuario', 'usuario')
        .select([
          'carona',
          'usuario.idUsuario',
          'usuario.nome',
        ])

        .where('carona.status = :status', {
          status: 'ATIVA',
        })

        // Remove caronas unicas antigas e recorrencias encerradas.
        .andWhere(`
          (
            carona.dataInicio >= CURDATE()
            OR (
              carona.recorrente = true
              AND (
                carona.dataFim IS NULL
                OR carona.dataFim >= CURDATE()
              )
            )
          )
        `)

        // Mostra primeiro as caronas mais proximas.
        .orderBy('carona.dataInicio', 'ASC')
        .addOrderBy('carona.horario', 'ASC')
        .getMany();
  }
}