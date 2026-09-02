import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, SelectQueryBuilder } from 'typeorm';

import { AvaliacoesService } from '../avaliacoes/avaliacoes.service';
import { Carona } from '../caronas/carona.entity';
import { CaronasService } from '../caronas/caronas.service';
import { PontoEmbarque } from '../caronas/ponto-embarque.entity';
import { Conversa } from '../mensagens/conversa.entity';
import { Solicitacao } from './solicitacao.entity';

export interface DadosNovaSolicitacao {
  idCarona: number;
  idPassageiro: number;
  tipoPontoEmbarque: 'EXISTENTE' | 'NOVO_SOLICITADO';
  idPontoEmbarque?: number;
  localEmbarque?: string;
  embarqueLatitude?: number;
  embarqueLongitude?: number;
}

interface DadosEmbarquePreparados {
  pontoEmbarque: PontoEmbarque | null;
  localEmbarque: string;
  latitude: number;
  longitude: number;
}

@Injectable()
export class SolicitacoesService {
  constructor(
    @InjectRepository(Solicitacao)
    private readonly solicitacoesRepository: Repository<Solicitacao>,

    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,

    @InjectRepository(PontoEmbarque)
    private readonly pontosEmbarqueRepository: Repository<PontoEmbarque>,

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

    const embarque = await this.prepararDadosEmbarque(dados);

    // Uma solicitação antiga recusada/cancelada pode ser reutilizada.
    if (existente) {
      existente.pontoEmbarque = embarque.pontoEmbarque;
      existente.tipoPontoEmbarque = dados.tipoPontoEmbarque;
      existente.localEmbarque = embarque.localEmbarque;
      existente.embarqueLatitude = embarque.latitude;
      existente.embarqueLongitude = embarque.longitude;
      existente.status = 'PENDENTE';

      return this.solicitacoesRepository.save(existente);
    }

    const novaSolicitacao = this.solicitacoesRepository.create({
      carona: { idCarona: dados.idCarona },
      passageiro: { idUsuario: dados.idPassageiro },
      pontoEmbarque: embarque.pontoEmbarque,
      tipoPontoEmbarque: dados.tipoPontoEmbarque,
      localEmbarque: embarque.localEmbarque,
      embarqueLatitude: embarque.latitude,
      embarqueLongitude: embarque.longitude,
      status: 'PENDENTE',
    });

    return this.solicitacoesRepository.save(novaSolicitacao);
  }

  private async prepararDadosEmbarque(
    dados: DadosNovaSolicitacao,
  ): Promise<DadosEmbarquePreparados> {
    if (dados.tipoPontoEmbarque === 'EXISTENTE') {
      if (!dados.idPontoEmbarque || !Number.isInteger(dados.idPontoEmbarque)) {
        throw new BadRequestException(
          'Selecione um ponto de embarque válido',
        );
      }

      // Além de existir, o ponto precisa pertencer à carona solicitada.
      const ponto = await this.pontosEmbarqueRepository.findOne({
        where: {
          idPontoEmbarque: dados.idPontoEmbarque,
          carona: { idCarona: dados.idCarona },
        },
      });

      if (!ponto) {
        throw new BadRequestException(
          'O ponto de embarque não pertence a esta carona',
        );
      }

      return {
        pontoEmbarque: ponto,
        localEmbarque: ponto.endereco,
        latitude: Number(ponto.latitude),
        longitude: Number(ponto.longitude),
      };
    }

    if (dados.tipoPontoEmbarque === 'NOVO_SOLICITADO') {
      const local = dados.localEmbarque?.trim() ?? '';
      const latitude = Number(dados.embarqueLatitude);
      const longitude = Number(dados.embarqueLongitude);

      if (!local || local.length > 255) {
        throw new BadRequestException('Local de embarque inválido');
      }

      if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
        throw new BadRequestException('Latitude do embarque inválida');
      }

      if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
        throw new BadRequestException('Longitude do embarque inválida');
      }

      return {
        pontoEmbarque: null,
        localEmbarque: local,
        latitude,
        longitude,
      };
    }

    throw new BadRequestException('Tipo de ponto de embarque inválido');
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
      .leftJoinAndSelect('solicitacao.pontoEmbarque', 'pontoEmbarque')
      .select([
        'solicitacao',
        'pontoEmbarque',
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
      .leftJoinAndSelect('solicitacao.pontoEmbarque', 'pontoEmbarque')
      .select([
        'solicitacao',
        'pontoEmbarque',
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
      const pontosRepository = manager.getRepository(PontoEmbarque);
      const conversasRepository = manager.getRepository(Conversa);

      const solicitacao = await solicitacoesRepository
        .createQueryBuilder('solicitacao')
        .innerJoinAndSelect('solicitacao.carona', 'carona')
        .innerJoinAndSelect('carona.usuario', 'motorista')
        .leftJoinAndSelect('solicitacao.pontoEmbarque', 'pontoEmbarque')
        .where('solicitacao.idSolicitacao = :idSolicitacao', {
          idSolicitacao,
        })
        // O ponto opcional fica fora do bloqueio; a carona protege as vagas.
        .setLock('pessimistic_write', undefined, ['solicitacao', 'carona'])
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

        // Um ponto sugerido só vira oficial depois da aprovação do motorista.
        if (solicitacao.tipoPontoEmbarque === 'NOVO_SOLICITADO') {
          const quantidadePontos = await pontosRepository.count({
            where: {
              carona: { idCarona: solicitacao.carona.idCarona },
            },
          });

          const novoPonto = pontosRepository.create({
            nome: null,
            endereco: solicitacao.localEmbarque,
            latitude: Number(solicitacao.embarqueLatitude),
            longitude: Number(solicitacao.embarqueLongitude),
            ordem: quantidadePontos + 1,
            carona: { idCarona: solicitacao.carona.idCarona },
          });

          solicitacao.pontoEmbarque =
              await pontosRepository.save(novoPonto);

          /*
           * Mantém NOVO_SOLICITADO no histórico.
           * Assim dá para saber que esse ponto nasceu de uma sugestão.
           */
        }

        solicitacao.carona.vagas -= 1;

        if (solicitacao.carona.vagas === 0) {
          solicitacao.carona.status = 'LOTADA';
        }

        await caronasRepository.save(solicitacao.carona);
      }

      solicitacao.status = novoStatus;
      const solicitacaoSalva = await solicitacoesRepository.save(solicitacao);

      if (novoStatus === 'ACEITA') {
        const conversaExistente = await conversasRepository.findOne({
          where: { solicitacao: { idSolicitacao } },
        });

        if (!conversaExistente) {
          const conversa = conversasRepository.create({
            solicitacao: { idSolicitacao },
          });
          await conversasRepository.save(conversa);
        }
      }

      return solicitacaoSalva;
    });
  }

  async cancelarSolicitacao(
    idSolicitacao: number,
    idUsuario: number,
  ): Promise<Solicitacao> {
    await this.atualizarCaronasVencidas();

    return this.dataSource.transaction(async (manager) => {
      const solicitacoesRepository = manager.getRepository(Solicitacao);
      const caronasRepository = manager.getRepository(Carona);

      const solicitacao = await solicitacoesRepository
        .createQueryBuilder('solicitacao')
        .innerJoinAndSelect('solicitacao.carona', 'carona')
        .innerJoinAndSelect('carona.usuario', 'motorista')
        .innerJoinAndSelect('solicitacao.passageiro', 'passageiro')
        .where('solicitacao.idSolicitacao = :idSolicitacao', {
          idSolicitacao,
        })
        .setLock('pessimistic_write')
        .getOne();

      if (!solicitacao) {
        throw new NotFoundException('Solicitação não encontrada');
      }

      const passageiroCancelando =
        solicitacao.passageiro.idUsuario === idUsuario;

      const motoristaCancelando =
        solicitacao.carona.usuario.idUsuario === idUsuario;

      if (!passageiroCancelando && !motoristaCancelando) {
        throw new BadRequestException(
          'Você não pode cancelar esta solicitação',
        );
      }

      if (
        solicitacao.carona.status === 'FINALIZADA' ||
        solicitacao.carona.status === 'CANCELADA'
      ) {
        throw new ConflictException('Esta carona já foi encerrada');
      }

      if (
        solicitacao.status !== 'PENDENTE' &&
        solicitacao.status !== 'ACEITA'
      ) {
        throw new ConflictException(
          'Esta solicitação não pode ser cancelada',
        );
      }

      if (solicitacao.status === 'ACEITA') {
        solicitacao.carona.vagas = Math.min(
          solicitacao.carona.vagas + 1,
          4,
        );

        if (solicitacao.carona.status === 'LOTADA') {
          solicitacao.carona.status = 'ATIVA';
        }

        await caronasRepository.save(solicitacao.carona);
      }

      solicitacao.status = passageiroCancelando
        ? 'CANCELADA_PASSAGEIRO'
        : 'CANCELADA_MOTORISTA';

      return solicitacoesRepository.save(solicitacao);
    });
  }

  private async atualizarCaronasVencidas(): Promise<void> {
    await this.caronasService.finalizarCaronasVencidas();

    // Pedidos pendentes expiram quando a carona termina.
    await this.solicitacoesRepository
      .createQueryBuilder()
      .update(Solicitacao)
      .set({ status: 'EXPIRADA' })
      .where('status = :statusPendente', { statusPendente: 'PENDENTE' })
      .andWhere(
        `id_carona IN (
          SELECT id_carona
          FROM unicarona.caronas
          WHERE status = :statusCarona
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
