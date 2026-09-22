import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';

import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';

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

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,

    @InjectRepository(PontoEmbarque)
    private readonly pontosEmbarqueRepository: Repository<PontoEmbarque>,

    @InjectRepository(PosicaoAtualCarona)
    private readonly posicoesRepository: Repository<PosicaoAtualCarona>,

    @InjectRepository(Solicitacao)
    private readonly solicitacoesRepository: Repository<Solicitacao>,

    private readonly dataSource: DataSource,
    private readonly usersService: UsersService,
  ) {}

  // Cria a carona e os pontos de embarque juntos.
  async criarCarona(dados: DadosCriacaoCarona): Promise<Carona> {
    const veiculo = await this.usersService.buscarVeiculo(dados.idUsuario);

    if (!veiculo) {
      throw new BadRequestException(
        'Cadastre seu veículo no perfil antes de oferecer uma carona',
      );
    }

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
          usuario: { veiculo: true },
          pontosEmbarque: true,
        },
      });

      if (!caronaCompleta) {
        throw new NotFoundException('Carona não encontrada');
      }

      caronaCompleta.pontosEmbarque.sort((a, b) => a.ordem - b.ordem);

      return caronaCompleta;
    });
  }

  async atualizarCarona(
    idCarona: number,
    dados: DadosCriacaoCarona,
  ): Promise<Carona> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, dados.idUsuario);

    if (carona.status === 'EM_ANDAMENTO') {
      throw new ConflictException(
        'Não é possível editar uma corrida em andamento',
      );
    }

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

  async excluirCarona(idCarona: number, idUsuario: number): Promise<void> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, idUsuario);

    if (carona.status === 'EM_ANDAMENTO') {
      throw new ConflictException(
        'Não é possível excluir uma corrida em andamento',
      );
    }

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
          AND (data_inicio + horario + INTERVAL '2 hours') <=
            (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')
        )
        OR
        (
          recorrente = true
          AND data_fim IS NOT NULL
          AND (data_fim + horario) <=
            (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')
        )
        `,
      )
      .execute();
  }

  async iniciarCarona(
    idCarona: number,
    idUsuario: number,
    agora = new Date(),
  ): Promise<Carona> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, idUsuario);

    if (carona.recorrente) {
      throw new BadRequestException(
        'O início de caronas recorrentes ainda não está disponível',
      );
    }
    if (carona.status !== 'ATIVA' && carona.status !== 'LOTADA') {
      throw new ConflictException('Esta carona não pode ser iniciada');
    }

    const horarioMarcado = this.obterHorarioMarcado(carona);
    const horarioAtual = this.obterHorarioBrasilia(agora);
    const umaHora = 60 * 60 * 1000;
    if (
      horarioAtual < horarioMarcado - umaHora ||
      horarioAtual > horarioMarcado + 2 * umaHora
    ) {
      throw new ConflictException(
        'A corrida pode ser iniciada entre 1 hora antes e 2 horas depois do horário marcado',
      );
    }

    carona.status = 'EM_ANDAMENTO';
    return this.caronasRepository.save(carona);
  }

  async finalizarCarona(idCarona: number, idUsuario: number): Promise<Carona> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, idUsuario);

    if (carona.recorrente) {
      throw new BadRequestException(
        'A finalização de caronas recorrentes ainda não está disponível',
      );
    }
    if (carona.status !== 'EM_ANDAMENTO') {
      throw new ConflictException(
        'Somente uma corrida em andamento pode ser finalizada',
      );
    }

    carona.status = 'FINALIZADA';
    const caronaFinalizada = await this.caronasRepository.save(carona);
    await this.posicoesRepository.delete({ idCarona });
    return caronaFinalizada;
  }

  async atualizarPosicaoAtual(
    idCarona: number,
    idUsuario: number,
    dados: DadosPosicaoAtualCarona,
  ): Promise<PosicaoAtualCarona> {
    const carona = await this.buscarCaronaDoUsuario(idCarona, idUsuario);

    if (carona.status !== 'EM_ANDAMENTO') {
      throw new ConflictException(
        'A localização só pode ser atualizada durante a corrida',
      );
    }

    const posicaoExistente = await this.posicoesRepository.findOne({
      where: { idCarona },
    });
    const posicao =
      posicaoExistente ?? this.posicoesRepository.create({ idCarona });

    posicao.latitude = dados.latitude;
    posicao.longitude = dados.longitude;
    posicao.direcao = dados.direcao;
    posicao.precisao = dados.precisao;

    return this.posicoesRepository.save(posicao);
  }

  async buscarPosicaoAtual(
    idCarona: number,
    idUsuario: number,
  ): Promise<PosicaoAtualCarona | null> {
    const carona = await this.caronasRepository.findOne({
      where: { idCarona },
      relations: { usuario: true },
    });

    if (!carona) {
      throw new NotFoundException('Carona não encontrada');
    }

    const motorista = carona.usuario.idUsuario === idUsuario;
    const passageiroAceito = motorista
      ? false
      : await this.solicitacoesRepository.exists({
          where: {
            carona: { idCarona },
            passageiro: { idUsuario },
            status: 'ACEITA',
          },
        });

    if (!motorista && !passageiroAceito) {
      throw new ForbiddenException(
        'Você não pode acompanhar a localização desta corrida',
      );
    }

    if (carona.status !== 'EM_ANDAMENTO') {
      throw new ConflictException('Esta corrida não está em andamento');
    }

    return this.posicoesRepository.findOne({ where: { idCarona } });
  }

  // Lista as caronas que ainda estão disponíveis.
  async listarCaronas(idUsuario: number): Promise<Carona[]> {
    await this.finalizarCaronasVencidas();

    const caronas = await this.caronasRepository
      .createQueryBuilder('carona')

      .leftJoinAndSelect('carona.usuario', 'usuario')

      .leftJoinAndSelect('usuario.veiculo', 'veiculo')

      .leftJoinAndSelect('carona.pontosEmbarque', 'pontoEmbarque')

      .select([
        'carona',
        'usuario.idUsuario',
        'usuario.nome',
        'veiculo',
        'pontoEmbarque',
      ])

      .where('carona.status = :status', {
        status: 'ATIVA',
      })

      // Não mostra a própria carona na tela de busca.
      .andWhere('usuario.idUsuario <> :idUsuario', {
        idUsuario,
      })

      .andWhere(
        `NOT EXISTS (
          SELECT 1
          FROM unicarona.solicitacoes solicitacao_usuario
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
          carona.dataInicio >=
            (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date
          OR (
            carona.recorrente = true
            AND (
              carona.dataFim IS NULL
              OR carona.dataFim >=
                (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date
            )
          )
        )
        `,
      )

      .orderBy('carona.dataInicio', 'ASC')
      .addOrderBy('carona.horario', 'ASC')
      .addOrderBy('pontoEmbarque.ordem', 'ASC')

      .getMany();

    return caronas;
  }

  async listarMinhasCaronas(idUsuario: number): Promise<Carona[]> {
    await this.finalizarCaronasVencidas();

    return this.caronasRepository
      .createQueryBuilder('carona')

      .innerJoinAndSelect('carona.usuario', 'usuario')

      .leftJoinAndSelect('usuario.veiculo', 'veiculo')

      .leftJoinAndSelect('carona.pontosEmbarque', 'pontoEmbarque')

      .select([
        'carona',
        'usuario.idUsuario',
        'usuario.nome',
        'veiculo',
        'pontoEmbarque',
      ])

      .where('usuario.idUsuario = :idUsuario', {
        idUsuario,
      })

      .andWhere('carona.status <> :statusCancelada', {
        statusCancelada: 'CANCELADA',
      })

      .orderBy('carona.dataInicio', 'DESC')
      .addOrderBy('carona.horario', 'DESC')
      .addOrderBy('pontoEmbarque.ordem', 'ASC')

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
        usuario: { veiculo: true },
        pontosEmbarque: true,
      },
    });

    // Não deixa outro usuário mexer na carona.
    if (!carona || carona.usuario.idUsuario !== idUsuario) {
      throw new NotFoundException('Carona não encontrada');
    }

    carona.pontosEmbarque ??= [];
    carona.pontosEmbarque.sort((a, b) => a.ordem - b.ordem);

    return carona;
  }

  private obterHorarioMarcado(carona: Carona): number {
    const [ano, mes, dia] = carona.dataInicio.split('-').map(Number);
    const [hora, minuto, segundo = 0] = carona.horario.split(':').map(Number);
    return Date.UTC(ano, mes - 1, dia, hora, minuto, segundo);
  }

  private obterHorarioBrasilia(data: Date): number {
    const partes = new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/Sao_Paulo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(data);
    const valor = (tipo: Intl.DateTimeFormatPartTypes) =>
      Number(partes.find((parte) => parte.type === tipo)?.value);
    return Date.UTC(
      valor('year'),
      valor('month') - 1,
      valor('day'),
      valor('hour'),
      valor('minute'),
      valor('second'),
    );
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
