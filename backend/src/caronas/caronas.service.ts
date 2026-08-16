import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';

import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';

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

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,

    @InjectRepository(PontoEmbarque)
    private readonly pontosEmbarqueRepository: Repository<PontoEmbarque>,

    private readonly dataSource: DataSource,
  ) {}

  // Cria a carona e os pontos de embarque juntos.
  async criarCarona(dados: DadosCriacaoCarona): Promise<Carona> {
    return this.dataSource.transaction(async (manager) => {
      const caronasRepository = manager.getRepository(Carona);
      const pontosRepository = manager.getRepository(PontoEmbarque);

      const novaCarona = caronasRepository.create({
        status: 'ATIVA',
        usuario: {
          idUsuario: dados.idUsuario,
        },
      });

      this.aplicarDados(novaCarona, dados);

      // Primeiro salva a carona para gerar o id_carona.
      const caronaSalva = await caronasRepository.save(novaCarona);

      // Depois salva os pontos ligados a essa carona.
      if (dados.pontosEmbarque.length > 0) {
        const pontos = dados.pontosEmbarque.map((ponto) =>
          pontosRepository.create({
            nome: ponto.nome,
            endereco: ponto.endereco,
            latitude: ponto.latitude,
            longitude: ponto.longitude,
            ordem: ponto.ordem,
            carona: {
              idCarona: caronaSalva.idCarona,
            },
          }),
        );

        await pontosRepository.save(pontos);
      }

      // Retorna a carona já com motorista e pontos carregados.
      const caronaCompleta = await caronasRepository.findOne({
        where: {
          idCarona: caronaSalva.idCarona,
        },
        relations: {
          usuario: true,
          pontosEmbarque: true,
        },
      });

      if (!caronaCompleta) {
        throw new NotFoundException('Carona não encontrada');
      }

      caronaCompleta.pontosEmbarque.sort(
        (a, b) => a.ordem - b.ordem,
      );

      return caronaCompleta;
    });
  }

  async atualizarCarona(
    idCarona: number,
    dados: DadosCriacaoCarona,
  ): Promise<Carona> {
    const carona = await this.buscarCaronaDoUsuario(
      idCarona,
      dados.idUsuario,
    );

    this.aplicarDados(carona, dados);

    if (carona.status === 'LOTADA' && carona.vagas > 0) {
      carona.status = 'ATIVA';
    }

    await this.caronasRepository.save(carona);

    /*
     * Por enquanto não vamos substituir os pontos na edição.
     * Primeiro vamos terminar o cadastro deles no Flutter.
     */
    return carona;
  }

  async excluirCarona(
    idCarona: number,
    idUsuario: number,
  ): Promise<void> {
    const carona = await this.buscarCaronaDoUsuario(
      idCarona,
      idUsuario,
    );

    // Mantém a carona no histórico.
    carona.status = 'CANCELADA';

    await this.caronasRepository.save(carona);
  }

  async finalizarCaronasVencidas(): Promise<void> {
    await this.caronasRepository
      .createQueryBuilder()
      .update(Carona)
      .set({
        status: 'FINALIZADA',
      })
      .where('status IN (:...status)', {
        status: ['ATIVA', 'LOTADA'],
      })
      .andWhere(
        `
        (
          recorrente = false
          AND TIMESTAMP(data_inicio, horario) <= NOW()
        )
        OR
        (
          recorrente = true
          AND data_fim IS NOT NULL
          AND TIMESTAMP(data_fim, horario) <= NOW()
        )
        `,
      )
      .execute();
  }

  // Lista as caronas que ainda estão disponíveis.
  async listarCaronas(idUsuario: number): Promise<Carona[]> {
    await this.finalizarCaronasVencidas();

    const caronas = await this.caronasRepository
      .createQueryBuilder('carona')

      .leftJoinAndSelect(
        'carona.usuario',
        'usuario',
      )

      .leftJoinAndSelect(
        'carona.pontosEmbarque',
        'pontoEmbarque',
      )

      .select([
        'carona',
        'usuario.idUsuario',
        'usuario.nome',
        'pontoEmbarque',
      ])

      .where('carona.status = :status', {
        status: 'ATIVA',
      })

      // Não mostra a própria carona na tela de busca.
      .andWhere(
        'usuario.idUsuario <> :idUsuario',
        {
          idUsuario,
        },
      )

      .andWhere(
        `NOT EXISTS (
          SELECT 1
          FROM solicitacoes solicitacao_usuario
          WHERE solicitacao_usuario.id_carona = carona.id_carona
            AND solicitacao_usuario.id_passageiro = :idUsuario
            AND solicitacao_usuario.status IN ('ACEITA', 'RECUSADA')
        )`,
        {
          idUsuario,
        },
      )

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

      .orderBy(
        'carona.dataInicio',
        'ASC',
      )
      .addOrderBy(
        'carona.horario',
        'ASC',
      )
      .addOrderBy(
        'pontoEmbarque.ordem',
        'ASC',
      )

      .getMany();

    return caronas;
  }

  async listarMinhasCaronas(
    idUsuario: number,
  ): Promise<Carona[]> {
    await this.finalizarCaronasVencidas();

    return this.caronasRepository
      .createQueryBuilder('carona')

      .innerJoinAndSelect(
        'carona.usuario',
        'usuario',
      )

      .leftJoinAndSelect(
        'carona.pontosEmbarque',
        'pontoEmbarque',
      )

      .select([
        'carona',
        'usuario.idUsuario',
        'usuario.nome',
        'pontoEmbarque',
      ])

      .where(
        'usuario.idUsuario = :idUsuario',
        {
          idUsuario,
        },
      )

      .andWhere(
        'carona.status <> :statusCancelada',
        {
          statusCancelada: 'CANCELADA',
        },
      )

      .orderBy(
        'carona.dataInicio',
        'DESC',
      )
      .addOrderBy(
        'carona.horario',
        'DESC',
      )
      .addOrderBy(
        'pontoEmbarque.ordem',
        'ASC',
      )

      .getMany();
  }

  private async buscarCaronaDoUsuario(
    idCarona: number,
    idUsuario: number,
  ): Promise<Carona> {
    const carona = await this.caronasRepository.findOne({
      where: {
        idCarona,
      },
      relations: {
        usuario: true,
        pontosEmbarque: true,
      },
    });

    // Não deixa outro usuário mexer na carona.
    if (
      !carona ||
      carona.usuario.idUsuario !== idUsuario
    ) {
      throw new NotFoundException(
        'Carona não encontrada',
      );
    }

    carona.pontosEmbarque.sort(
      (a, b) => a.ordem - b.ordem,
    );

    return carona;
  }

  private aplicarDados(
    carona: Carona,
    dados: DadosCriacaoCarona,
  ): void {
    const possuiRecorrencia =
        dados.recorrente === true;

    carona.origem = dados.origem;
    carona.origemCidade = dados.origemCidade;
    carona.origemLatitude = dados.origemLatitude;
    carona.origemLongitude = dados.origemLongitude;

    carona.destino = dados.destino;
    carona.destinoCidade = dados.destinoCidade;
    carona.destinoLatitude = dados.destinoLatitude;
    carona.destinoLongitude = dados.destinoLongitude;

    carona.dataInicio = dados.dataInicio;

    carona.dataFim = possuiRecorrencia
        ? dados.dataFim
        : null;

    carona.horario = dados.horario;
    carona.vagas = dados.vagas;
    carona.valor = dados.valor;

    carona.recorrente = possuiRecorrencia;

    carona.diasSemana = possuiRecorrencia
        ? dados.diasSemana
        : null;

    carona.observacoes =
        dados.observacoes?.trim() || null;
  }
}