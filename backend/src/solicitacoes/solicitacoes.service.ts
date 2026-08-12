import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, SelectQueryBuilder } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
import { CaronasService } from '../caronas/caronas.service';
import { AvaliacoesService } from '../avaliacoes/avaliacoes.service';
import { Solicitacao } from './solicitacao.entity';

export interface DadosNovaSolicitacao {
  idCarona: number;
  idPassageiro: number;
  localEmbarque: string;
  embarqueLatitude: number;
  embarqueLongitude: number;
}

@Injectable()
export class SolicitacoesService {
  constructor(
    @InjectRepository(Solicitacao)
    private readonly solicitacoesRepository: Repository<Solicitacao>,
    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,
    private readonly dataSource: DataSource,
    private readonly caronasService: CaronasService,
    private readonly avaliacoesService: AvaliacoesService,
  ) {}

  async criarSolicitacao(dados: DadosNovaSolicitacao): Promise<Solicitacao> {
    await this.atualizarCaronasVencidas();

    const carona = await this.caronasRepository.findOne({
      where: { idCarona: dados.idCarona },
      relations: { usuario: true },
    });

    if (!carona) {
      throw new NotFoundException('Carona não encontrada');
    }

    if (carona.status !== 'ATIVA' || carona.vagas <= 0) {
      throw new ConflictException('Esta carona não está disponível');
    }

    if (carona.usuario.idUsuario === dados.idPassageiro) {
      throw new BadRequestException(
        'Você não pode solicitar vaga na própria carona',
      );
    }

    const existente = await this.solicitacoesRepository.findOne({
      where: {
        carona: { idCarona: dados.idCarona },
        passageiro: { idUsuario: dados.idPassageiro },
      },
    });

    if (
      existente &&
      (existente.status === 'PENDENTE' || existente.status === 'ACEITA')
    ) {
      throw new ConflictException('Você já solicitou vaga nesta carona');
    }

    if (existente) {
      existente.localEmbarque = dados.localEmbarque.trim();
      existente.embarqueLatitude = dados.embarqueLatitude;
      existente.embarqueLongitude = dados.embarqueLongitude;
      existente.status = 'PENDENTE';

      return this.solicitacoesRepository.save(existente);
    }

    const novaSolicitacao = this.solicitacoesRepository.create({
      carona: { idCarona: dados.idCarona },
      passageiro: { idUsuario: dados.idPassageiro },
      localEmbarque: dados.localEmbarque.trim(),
      embarqueLatitude: dados.embarqueLatitude,
      embarqueLongitude: dados.embarqueLongitude,
      status: 'PENDENTE',
    });

    return this.solicitacoesRepository.save(novaSolicitacao);
  }

  async listarRecebidas(idMotorista: number): Promise<Solicitacao[]> {
    await this.atualizarCaronasVencidas();
    const solicitacoes = await this.consultaRecebidas(idMotorista).getMany();
    return this.marcarAvaliacoes(solicitacoes, idMotorista);
  }

  async listarRecebidasDaCarona(
    idMotorista: number,
    idCarona: number,
  ): Promise<Solicitacao[]> {
    await this.atualizarCaronasVencidas();
    const solicitacoes = await this.consultaRecebidas(idMotorista)
      .andWhere('carona.idCarona = :idCarona', { idCarona })
      .getMany();
    return this.marcarAvaliacoes(solicitacoes, idMotorista);
  }

  private consultaRecebidas(
    idMotorista: number,
  ): SelectQueryBuilder<Solicitacao> {
    return this.solicitacoesRepository
      .createQueryBuilder('solicitacao')
      .innerJoinAndSelect('solicitacao.carona', 'carona')
      .innerJoin('carona.usuario', 'motorista')
      .innerJoinAndSelect('solicitacao.passageiro', 'passageiro')
      .select([
        'solicitacao',
        'carona.idCarona',
        'carona.destino',
        'carona.dataInicio',
        'carona.horario',
        'carona.status',
        'carona.recorrente',
        'carona.diasSemana',
        'passageiro.idUsuario',
        'passageiro.nome',
      ])
      .where('motorista.idUsuario = :idMotorista', { idMotorista })
      .orderBy("CASE WHEN solicitacao.status = 'PENDENTE' THEN 0 ELSE 1 END")
      .addOrderBy('solicitacao.criadoEm', 'DESC');
  }

  async listarEnviadas(idPassageiro: number): Promise<Solicitacao[]> {
    await this.atualizarCaronasVencidas();
    const solicitacoes = await this.solicitacoesRepository
      .createQueryBuilder('solicitacao')
      .innerJoinAndSelect('solicitacao.carona', 'carona')
      .innerJoinAndSelect('carona.usuario', 'motorista')
      .innerJoin('solicitacao.passageiro', 'passageiro')
      .select([
        'solicitacao',
        'carona.idCarona',
        'carona.destino',
        'carona.dataInicio',
        'carona.horario',
        'carona.valor',
        'carona.status',
        'carona.recorrente',
        'carona.diasSemana',
        'motorista.idUsuario',
        'motorista.nome',
      ])
      .where('passageiro.idUsuario = :idPassageiro', { idPassageiro })
      .orderBy("CASE WHEN solicitacao.status = 'PENDENTE' THEN 0 ELSE 1 END")
      .addOrderBy('solicitacao.criadoEm', 'DESC')
      .getMany();

    return this.marcarAvaliacoes(solicitacoes, idPassageiro);
  }

  async responderSolicitacao(
    idSolicitacao: number,
    idMotorista: number,
    novoStatus: 'ACEITA' | 'RECUSADA',
  ): Promise<Solicitacao> {
    await this.atualizarCaronasVencidas();

    return this.dataSource.transaction(async (manager) => {
      const solicitacoesRepository = manager.getRepository(Solicitacao);
      const caronasRepository = manager.getRepository(Carona);

      const solicitacao = await solicitacoesRepository
        .createQueryBuilder('solicitacao')
        .innerJoinAndSelect('solicitacao.carona', 'carona')
        .innerJoinAndSelect('carona.usuario', 'motorista')
        .where('solicitacao.idSolicitacao = :idSolicitacao', {
          idSolicitacao,
        })
        .setLock('pessimistic_write')
        .getOne();

      if (!solicitacao) {
        throw new NotFoundException('Solicitação não encontrada');
      }

      if (solicitacao.carona.usuario.idUsuario !== idMotorista) {
        throw new BadRequestException(
          'Você não pode responder esta solicitação',
        );
      }

      if (solicitacao.status !== 'PENDENTE') {
        throw new ConflictException('Esta solicitação já foi respondida');
      }

      if (novoStatus === 'ACEITA') {
        if (
          solicitacao.carona.status !== 'ATIVA' ||
          solicitacao.carona.vagas <= 0
        ) {
          throw new ConflictException('Não há vagas disponíveis');
        }

        solicitacao.carona.vagas -= 1;

        if (solicitacao.carona.vagas === 0) {
          solicitacao.carona.status = 'LOTADA';
        }

        await caronasRepository.save(solicitacao.carona);
      }

      solicitacao.status = novoStatus;

      return solicitacoesRepository.save(solicitacao);
    });
  }

  private async atualizarCaronasVencidas(): Promise<void> {
    await this.caronasService.finalizarCaronasVencidas();

    // Pedidos sem resposta deixam de ficar pendentes quando a carona termina.
    await this.solicitacoesRepository
      .createQueryBuilder()
      .update(Solicitacao)
      .set({ status: 'EXPIRADA' })
      .where('status = :statusPendente', { statusPendente: 'PENDENTE' })
      .andWhere(
        `id_carona IN (
          SELECT id_carona FROM caronas WHERE status = :statusCarona
        )`,
        { statusCarona: 'FINALIZADA' },
      )
      .execute();
  }

  private async marcarAvaliacoes(
    solicitacoes: Solicitacao[],
    idUsuario: number,
  ): Promise<Solicitacao[]> {
    const idsAvaliados =
      await this.avaliacoesService.buscarSolicitacoesAvaliadas(
        idUsuario,
        solicitacoes.map((item) => item.idSolicitacao),
      );

    for (const solicitacao of solicitacoes) {
      solicitacao.avaliada = idsAvaliados.has(solicitacao.idSolicitacao);
      solicitacao.podeAvaliar =
        !solicitacao.avaliada &&
        this.avaliacoesService.podeAvaliarSolicitacao(solicitacao);
    }

    return solicitacoes;
  }
}
