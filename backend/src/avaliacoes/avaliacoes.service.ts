import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { CaronasService } from '../caronas/caronas.service';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { UsersService } from '../users/users.service';
import { Avaliacao } from './avaliacao.entity';

interface ResumoBanco {
  media: string | null;
  total: string;
}

export interface AvaliacoesRecebidas {
  media: number;
  total: number;
  pagina: number;
  totalPaginas: number;
  avaliacoes: Avaliacao[];
}

@Injectable()
export class AvaliacoesService {
  constructor(
    @InjectRepository(Avaliacao)
    private readonly avaliacoesRepository: Repository<Avaliacao>,
    @InjectRepository(Solicitacao)
    private readonly solicitacoesRepository: Repository<Solicitacao>,
    private readonly usersService: UsersService,
    private readonly caronasService: CaronasService,
  ) {}

  async criar(
    idAvaliador: number,
    idSolicitacao: number,
    nota: number,
    comentario: string | null,
  ): Promise<Avaliacao> {
    await this.caronasService.finalizarCaronasVencidas();

    const solicitacao = await this.solicitacoesRepository.findOne({
      where: { idSolicitacao },
      relations: { passageiro: true, carona: { usuario: true } },
    });

    if (!solicitacao) {
      throw new NotFoundException('Solicitação não encontrada');
    }

    if (solicitacao.status !== 'ACEITA') {
      throw new ConflictException(
        'Somente solicitações aceitas podem ser avaliadas',
      );
    }

    if (!this.podeAvaliarSolicitacao(solicitacao)) {
      throw new ConflictException('A carona ainda não foi finalizada');
    }

    const idPassageiro = solicitacao.passageiro.idUsuario;
    const idMotorista = solicitacao.carona.usuario.idUsuario;

    if (idAvaliador !== idPassageiro && idAvaliador !== idMotorista) {
      throw new BadRequestException('Você não participou desta carona');
    }

    const avaliacaoExistente = await this.avaliacoesRepository.findOne({
      where: {
        solicitacao: { idSolicitacao },
        avaliador: { idUsuario: idAvaliador },
      },
    });

    if (avaliacaoExistente) {
      throw new ConflictException('Você já avaliou esta carona');
    }

    const idAvaliado =
      idAvaliador === idPassageiro ? idMotorista : idPassageiro;
    const novaAvaliacao = this.avaliacoesRepository.create({
      solicitacao: { idSolicitacao },
      avaliador: { idUsuario: idAvaliador },
      avaliado: { idUsuario: idAvaliado },
      nota,
      comentario: comentario?.trim() || null,
    });

    return this.avaliacoesRepository.save(novaAvaliacao);
  }

  podeAvaliarSolicitacao(
    solicitacao: Solicitacao,
    agora = new Date(),
  ): boolean {
    if (solicitacao.status !== 'ACEITA') {
      return false;
    }

    if (!solicitacao.carona.recorrente) {
      return solicitacao.carona.status === 'FINALIZADA';
    }

    const primeiraOcorrencia = this.buscarPrimeiraOcorrencia(solicitacao);
    return primeiraOcorrencia != null && primeiraOcorrencia <= agora;
  }

  async buscarSolicitacoesAvaliadas(
    idAvaliador: number,
    idsSolicitacoes: number[],
  ): Promise<Set<number>> {
    if (idsSolicitacoes.length === 0) {
      return new Set();
    }

    const registros = await this.avaliacoesRepository
      .createQueryBuilder('avaliacao')
      .innerJoin('avaliacao.solicitacao', 'solicitacao')
      .select('solicitacao.idSolicitacao', 'idSolicitacao')
      .where('avaliacao.id_avaliador = :idAvaliador', { idAvaliador })
      .andWhere('solicitacao.idSolicitacao IN (:...idsSolicitacoes)', {
        idsSolicitacoes,
      })
      .getRawMany<{ idSolicitacao: string }>();

    return new Set(registros.map((item) => Number(item.idSolicitacao)));
  }

  async listarRecebidas(
    idUsuario: number,
    pagina: number,
    limite = 20,
  ): Promise<AvaliacoesRecebidas> {
    const usuario = await this.usersService.buscarPorId(idUsuario);

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    const resumo = await this.avaliacoesRepository
      .createQueryBuilder('avaliacao')
      .select('COALESCE(AVG(avaliacao.nota), 0)', 'media')
      .addSelect('COUNT(avaliacao.idAvaliacao)', 'total')
      .where('avaliacao.id_avaliado = :idUsuario', { idUsuario })
      .getRawOne<ResumoBanco>();

    const total = Number(resumo?.total ?? 0);
    const media = Number(Number(resumo?.media ?? 0).toFixed(2));

    const avaliacoes = await this.avaliacoesRepository
      .createQueryBuilder('avaliacao')
      .innerJoinAndSelect('avaliacao.avaliador', 'avaliador')
      .select(['avaliacao', 'avaliador.idUsuario', 'avaliador.nome'])
      .where('avaliacao.id_avaliado = :idUsuario', { idUsuario })
      .orderBy('avaliacao.criadoEm', 'DESC')
      .skip((pagina - 1) * limite)
      .take(limite)
      .getMany();

    return {
      media,
      total,
      pagina,
      totalPaginas: total === 0 ? 0 : Math.ceil(total / limite),
      avaliacoes,
    };
  }

  private buscarPrimeiraOcorrencia(solicitacao: Solicitacao): Date | null {
    const carona = solicitacao.carona;
    const diasSemana = carona.diasSemana ?? [];

    if (diasSemana.length === 0) {
      return null;
    }

    const partesData = carona.dataInicio.split('-').map(Number);
    const partesHorario = carona.horario.split(':').map(Number);

    if (partesData.length !== 3 || partesHorario.length < 2) {
      return null;
    }

    const [ano, mes, dia] = partesData;
    const [hora, minuto, segundo = 0] = partesHorario;
    const inicio = new Date(ano, mes - 1, dia, hora, minuto, segundo);

    if (Number.isNaN(inicio.getTime())) {
      return null;
    }

    const aceitaEm = solicitacao.atualizadoEm ?? solicitacao.criadoEm;
    const dataBase = aceitaEm > inicio ? aceitaEm : inicio;
    const primeiroDia = new Date(
      dataBase.getFullYear(),
      dataBase.getMonth(),
      dataBase.getDate(),
      hora,
      minuto,
      segundo,
    );
    const nomesDias = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];

    for (let quantidadeDias = 0; quantidadeDias < 7; quantidadeDias++) {
      const data = new Date(primeiroDia);
      data.setDate(primeiroDia.getDate() + quantidadeDias);

      if (carona.dataFim != null && data > this.fimDoDia(carona.dataFim)) {
        return null;
      }

      if (
        data >= inicio &&
        data >= aceitaEm &&
        diasSemana.includes(nomesDias[data.getDay()])
      ) {
        return data;
      }
    }

    return null;
  }

  private fimDoDia(dataRecebida: string): Date {
    const [ano, mes, dia] = dataRecebida.split('-').map(Number);
    return new Date(ano, mes - 1, dia, 23, 59, 59);
  }
}
