import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { Conversa } from './conversa.entity';
import { Mensagem } from './mensagem.entity';

@Injectable()
export class MensagensService {
  constructor(
    @InjectRepository(Conversa)
    private readonly conversasRepository: Repository<Conversa>,
    @InjectRepository(Mensagem)
    private readonly mensagensRepository: Repository<Mensagem>,
    @InjectRepository(Solicitacao)
    private readonly solicitacoesRepository: Repository<Solicitacao>,
  ) {}

  async obterOuCriarConversa(
    idSolicitacao: number,
    idUsuario: number,
  ): Promise<Conversa> {
    const existente = await this.buscarPorSolicitacao(idSolicitacao);

    if (existente) {
      this.validarParticipante(existente, idUsuario);
      return existente;
    }

    const solicitacao = await this.solicitacoesRepository.findOne({
      where: { idSolicitacao },
      relations: {
        passageiro: true,
        carona: { usuario: true },
      },
    });

    if (!solicitacao) {
      throw new NotFoundException('Solicitação não encontrada');
    }

    this.validarParticipante({ solicitacao } as Conversa, idUsuario);

    if (solicitacao.status !== 'ACEITA') {
      throw new ConflictException(
        'O chat é liberado somente após a solicitação ser aceita',
      );
    }

    const conversa = this.conversasRepository.create({ solicitacao });

    try {
      return await this.conversasRepository.save(conversa);
    } catch (erro) {
      // Evita duplicação se motorista e passageiro abrirem o chat juntos.
      const criadaEmParalelo = await this.buscarPorSolicitacao(idSolicitacao);

      if (criadaEmParalelo) {
        return criadaEmParalelo;
      }

      throw erro;
    }
  }

  async listarConversas(idUsuario: number) {
    const conversas = await this.conversasRepository
      .createQueryBuilder('conversa')
      .innerJoinAndSelect('conversa.solicitacao', 'solicitacao')
      .innerJoinAndSelect('solicitacao.carona', 'carona')
      .innerJoinAndSelect('carona.usuario', 'motorista')
      .innerJoinAndSelect('solicitacao.passageiro', 'passageiro')
      .where(
        '(motorista.idUsuario = :idUsuario OR passageiro.idUsuario = :idUsuario)',
        { idUsuario },
      )
      .orderBy('conversa.criadoEm', 'DESC')
      .getMany();

    return Promise.all(
      conversas.map(async (conversa) => ({
        conversa,
        ultimaMensagem: await this.mensagensRepository.findOne({
          where: { conversa: { idConversa: conversa.idConversa } },
          relations: { remetente: true },
          order: { criadoEm: 'DESC' },
        }),
      })),
    );
  }

  async listarMensagens(
    idConversa: number,
    idUsuario: number,
    antesDe?: number,
  ): Promise<Mensagem[]> {
    await this.buscarConversaPermitida(idConversa, idUsuario);

    const mensagens = await this.mensagensRepository.find({
      where: {
        conversa: { idConversa },
        ...(antesDe ? { idMensagem: LessThan(antesDe) } : {}),
      },
      relations: { remetente: true },
      order: { idMensagem: 'DESC' },
      take: 50,
    });

    return mensagens.reverse();
  }

  async enviarMensagem(
    idConversa: number,
    idUsuario: number,
    conteudo: string,
  ): Promise<Mensagem> {
    const conversa = await this.buscarConversaPermitida(idConversa, idUsuario);

    if (conversa.solicitacao.status !== 'ACEITA') {
      throw new ConflictException('Esta conversa está encerrada');
    }

    const texto = conteudo.trim();

    if (!texto || texto.length > 1000) {
      throw new BadRequestException('Mensagem inválida');
    }

    const mensagem = this.mensagensRepository.create({
      conversa: { idConversa },
      remetente: { idUsuario },
      conteudo: texto,
    });

    return this.mensagensRepository.save(mensagem);
  }

  private buscarPorSolicitacao(
    idSolicitacao: number,
  ): Promise<Conversa | null> {
    return this.conversasRepository.findOne({
      where: { solicitacao: { idSolicitacao } },
      relations: {
        solicitacao: {
          passageiro: true,
          carona: { usuario: true },
        },
      },
    });
  }

  private async buscarConversaPermitida(
    idConversa: number,
    idUsuario: number,
  ): Promise<Conversa> {
    const conversa = await this.conversasRepository.findOne({
      where: { idConversa },
      relations: {
        solicitacao: {
          passageiro: true,
          carona: { usuario: true },
        },
      },
    });

    if (!conversa) {
      throw new NotFoundException('Conversa não encontrada');
    }

    this.validarParticipante(conversa, idUsuario);
    return conversa;
  }

  private validarParticipante(conversa: Conversa, idUsuario: number): void {
    const solicitacao = conversa.solicitacao;
    const idPassageiro = solicitacao.passageiro.idUsuario;
    const idMotorista = solicitacao.carona.usuario.idUsuario;

    if (idUsuario !== idPassageiro && idUsuario !== idMotorista) {
      throw new NotFoundException('Conversa não encontrada');
    }
  }
}
