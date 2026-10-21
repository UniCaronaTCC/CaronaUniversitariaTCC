import { RecorrenciaCarona } from './recorrencia.entity';
import {
  aplicarDadosCarona,
  DadosCriacaoCarona,
  DadosPosicaoAtualCarona,
  DadosEdicaoCarona,
} from './dados-carona';
export type {
  DadosCriacaoCarona,
  DadosPontoEmbarque,
  DadosPosicaoAtualCarona,
} from './dados-carona';
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';

import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';
import { PosicaoAtualCarona } from './posicao-atual-carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';
import { RecorrenciasService } from './recorrencias.service';

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
    private readonly recorrenciasService: RecorrenciasService,
  ) {}

  // Cria a carona e os pontos de embarque juntos.
  async criarCarona(dados: DadosCriacaoCarona): Promise<Carona> {
    const veiculo = await this.usersService.buscarVeiculo(dados.idUsuario);

    if (!veiculo) {
      throw new BadRequestException(
        'Cadastre seu veículo no perfil antes de oferecer uma carona',
      );
    }

    if (dados.recorrente) return this.recorrenciasService.criar(dados);

    await this.usersService.exigirCnhParaOferecerCarona(dados.idUsuario);

    return this.dataSource.transaction(async (manager) => {
      const caronasRepository = manager.getRepository(Carona);
      const pontosRepository = manager.getRepository(PontoEmbarque);

      const novaCarona = caronasRepository.create({
        status: 'ATIVA',
        usuario: {
          idUsuario: dados.idUsuario,
        },
      });

      aplicarDadosCarona(novaCarona, dados);

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
    dados: DadosEdicaoCarona,
  ): Promise<Carona> {
    return this.dataSource.transaction(async (manager) => {
      const carona = await this.bloquearCaronaEditavel(
        manager,
        idCarona,
        dados.idUsuario,
      );
      if (dados.recorrente || carona.recorrente) {
        throw new BadRequestException(
          'Gerencie a programação em Recorrências. Para uma carona antiga, cadastre uma nova programação.',
        );
      }
      if (carona.idRecorrencia && dados.dataInicio !== carona.dataInicio) {
        throw new BadRequestException(
          'A data desta carona pertence à programação. Cancele este dia e publique uma carona avulsa para outra data.',
        );
      }
      const capacidade = await this.calcularCapacidade(manager, carona);
      if (dados.capacidadeAnterior !== capacidade.capacidadePassageiros) {
        throw new ConflictException(
          'A capacidade foi alterada em outra edição. Reabra a carona antes de salvar',
        );
      }
      if (
        !Number.isInteger(dados.capacidadePassageiros) ||
        dados.capacidadePassageiros < 1 ||
        dados.capacidadePassageiros > 4
      ) {
        throw new BadRequestException(
          'Informe capacidade entre 1 e 4 passageiros',
        );
      }
      if (dados.capacidadePassageiros < capacidade.passageirosAceitos) {
        throw new ConflictException(
          'A capacidade não pode ser menor que a quantidade de passageiros aceitos. Reabra a carona para conferir as reservas',
        );
      }
      if (capacidade.passageirosAceitos > 0) {
        if (dados.capacidadePassageiros < capacidade.capacidadePassageiros) {
          throw new ConflictException(
            'Com passageiros aceitos, a capacidade só pode ser aumentada',
          );
        }
        const camposFixos = [
          'origem',
          'origemCidade',
          'origemLatitude',
          'origemLongitude',
          'destino',
          'destinoCidade',
          'destinoLatitude',
          'destinoLongitude',
          'dataInicio',
          'dataFim',
          'horario',
          'valor',
        ] as const;
        const pontos = await manager.getRepository(PontoEmbarque).find({
          where: { carona: { idCarona } },
          order: { ordem: 'ASC', idPontoEmbarque: 'ASC' },
        });
        const pontosAlterados =
          pontos.length !== dados.pontosEmbarque.length ||
          pontos.some((ponto, indice) => {
            const recebido = dados.pontosEmbarque[indice];
            return (
              ['nome', 'endereco', 'latitude', 'longitude', 'ordem'] as const
            ).some((campo) => ponto[campo] !== recebido[campo]);
          });
        if (
          camposFixos.some((campo) => carona[campo] !== dados[campo]) ||
          pontosAlterados
        ) {
          throw new ConflictException(
            'Há passageiros aceitos. Apenas observações e aumento de capacidade são permitidos. Reabra a carona para conferir as reservas',
          );
        }
        // Nao regrava os dados da viagem ja confirmados pelos passageiros.
        carona.vagas =
          dados.capacidadePassageiros - capacidade.passageirosAceitos;
        carona.observacoes = dados.observacoes?.trim() || null;
      } else {
        aplicarDadosCarona(carona, {
          ...dados,
          vagas: dados.capacidadePassageiros,
        });
      }
      carona.status = carona.vagas === 0 ? 'LOTADA' : 'ATIVA';
      const repository = manager.getRepository(Carona);
      await repository.save(carona);
      const atualizada = await repository.findOneOrFail({
        where: { idCarona },
        relations: { usuario: { veiculo: true }, pontosEmbarque: true },
      });
      atualizada.pontosEmbarque = (atualizada.pontosEmbarque ?? []).sort(
        (a, b) => a.ordem - b.ordem,
      );
      return atualizada;
    });
  }

  async buscarCapacidade(idCarona: number, idUsuario: number) {
    return this.dataSource.transaction(async (manager) => {
      const carona = await this.bloquearCaronaEditavel(
        manager,
        idCarona,
        idUsuario,
      );
      return this.calcularCapacidade(manager, carona);
    });
  }

  private async bloquearCaronaEditavel(
    manager: EntityManager,
    idCarona: number,
    idUsuario: number,
  ) {
    // O aceite, cancelamento e expiracao tambem bloqueiam esta mesma linha.
    const carona = await manager
      .getRepository(Carona)
      .createQueryBuilder('carona')
      .where('carona.idCarona = :idCarona', { idCarona })
      .andWhere('carona.id_usuario = :idUsuario', { idUsuario })
      .setLock('pessimistic_write')
      .getOne();
    if (!carona) throw new NotFoundException('Carona não encontrada');
    if (!['ATIVA', 'LOTADA'].includes(carona.status)) {
      throw new ConflictException(
        'Só é possível editar caronas ativas ou lotadas, antes do início da corrida',
      );
    }
    return carona;
  }

  private async calcularCapacidade(manager: EntityManager, carona: Carona) {
    const passageirosAceitos = await manager.getRepository(Solicitacao).count({
      where: { carona: { idCarona: carona.idCarona }, status: 'ACEITA' },
    });
    const capacidadePassageiros = carona.vagas + passageirosAceitos;
    if (
      !Number.isInteger(carona.vagas) ||
      carona.vagas < 0 ||
      capacidadePassageiros < 1 ||
      capacidadePassageiros > 4
    ) {
      throw new ConflictException(
        'As vagas desta carona estão inconsistentes. Não foi feita nenhuma alteração',
      );
    }
    return {
      capacidadePassageiros,
      passageirosAceitos,
      vagasDisponiveis: carona.vagas,
    };
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
      // Cadastros legados sem programação não geram novas datas de carona.
      .andWhere(
        `
        (
          (
            (recorrente = false OR id_recorrencia IS NULL)
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
      .leftJoinAndMapOne(
        'carona.programacao',
        RecorrenciaCarona,
        'programacao',
        'programacao.idRecorrencia = carona.idRecorrencia',
      )

      .innerJoinAndSelect('carona.usuario', 'usuario')

      .leftJoinAndSelect('usuario.veiculo', 'veiculo')

      .leftJoinAndSelect('carona.pontosEmbarque', 'pontoEmbarque')

      .select([
        'carona',
        'programacao.idRecorrencia',
        'programacao.diasSemana',
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

  async buscarDetalhesCarona(
    idCarona: number,
    idUsuario: number,
  ): Promise<Carona> {
    await this.finalizarCaronasVencidas();
    const carona = await this.caronasRepository.findOne({
      where: { idCarona },
      relations: { usuario: { veiculo: true }, pontosEmbarque: true },
    });

    if (!carona) throw new NotFoundException('Carona não encontrada');

    if (carona.usuario.idUsuario !== idUsuario) {
      const vinculado = await this.solicitacoesRepository.exists({
        where: { carona: { idCarona }, passageiro: { idUsuario } },
      });
      if (!vinculado) throw new NotFoundException('Carona não encontrada');
    }

    carona.pontosEmbarque ??= [];
    carona.pontosEmbarque.sort((a, b) => a.ordem - b.ordem);
    return carona;
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
}
