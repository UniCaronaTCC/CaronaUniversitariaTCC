import { Injectable, NotFoundException } from '@nestjs/common';
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
    const novaCarona = this.caronasRepository.create({
      status: 'ATIVA',
      usuario: {
        idUsuario: dados.idUsuario,
      },
    });

    this.aplicarDados(novaCarona, dados);

    return this.caronasRepository.save(novaCarona);
  }

  async atualizarCarona(
    idCarona: number,
    dados: DadosCriacaoCarona,
  ): Promise<Carona> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, dados.idUsuario);

    this.aplicarDados(carona, dados);

    if (carona.status === 'LOTADA' && carona.vagas > 0) {
      carona.status = 'ATIVA';
    }

    return this.caronasRepository.save(carona);
  }

  async excluirCarona(idCarona: number, idUsuario: number): Promise<void> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, idUsuario);

    // Mantém o histórico das solicitações relacionadas à oferta.
    carona.status = 'CANCELADA';
    await this.caronasRepository.save(carona);
  }

  // Lista somente ofertas ativas e que ainda podem acontecer.
  async listarCaronas(idUsuario: number): Promise<Carona[]> {
    return (
      this.caronasRepository
        .createQueryBuilder('carona')

        // Carrega somente identificacao e nome do motorista.
        .leftJoinAndSelect('carona.usuario', 'usuario')
        .select(['carona', 'usuario.idUsuario', 'usuario.nome'])

        .where('carona.status = :status', {
          status: 'ATIVA',
        })

        // A Home nunca mostra ofertas publicadas pelo proprio usuario.
        .andWhere('usuario.idUsuario <> :idUsuario', { idUsuario })

        // Depois da resposta do motorista, a carona passa para a area Caronas.
        .andWhere(
          `NOT EXISTS (
            SELECT 1
            FROM solicitacoes solicitacao_usuario
            WHERE solicitacao_usuario.id_carona = carona.id_carona
              AND solicitacao_usuario.id_passageiro = :idUsuario
              AND solicitacao_usuario.status IN ('ACEITA', 'RECUSADA')
          )`,
          { idUsuario },
        )

        // Remove caronas unicas antigas e recorrencias encerradas.
        .andWhere(
          `
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
        `,
        )

        // Mostra primeiro as caronas mais proximas.
        .orderBy('carona.dataInicio', 'ASC')
        .addOrderBy('carona.horario', 'ASC')
        .getMany()
    );
  }

  async listarMinhasCaronas(idUsuario: number): Promise<Carona[]> {
    return this.caronasRepository
      .createQueryBuilder('carona')
      .innerJoinAndSelect('carona.usuario', 'usuario')
      .select(['carona', 'usuario.idUsuario', 'usuario.nome'])
      .where('usuario.idUsuario = :idUsuario', { idUsuario })
      .andWhere('carona.status <> :statusCancelada', {
        statusCancelada: 'CANCELADA',
      })
      .andWhere(
        `
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
      `,
      )
      .orderBy('carona.dataInicio', 'ASC')
      .addOrderBy('carona.horario', 'ASC')
      .getMany();
  }

  private async buscarCaronaDoUsuario(
    idCarona: number,
    idUsuario: number,
  ): Promise<Carona> {
    const carona = await this.caronasRepository.findOne({
      where: { idCarona },
      relations: { usuario: true },
    });

    // A mesma resposta evita revelar a existência de caronas de outro usuário.
    if (!carona || carona.usuario.idUsuario !== idUsuario) {
      throw new NotFoundException('Carona não encontrada');
    }

    return carona;
  }

  private aplicarDados(carona: Carona, dados: DadosCriacaoCarona): void {
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
}
