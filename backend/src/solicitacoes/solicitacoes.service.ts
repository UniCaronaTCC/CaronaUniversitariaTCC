import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Carona } from '../caronas/carona.entity';
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
  ) {}

  async criarSolicitacao(dados: DadosNovaSolicitacao): Promise<Solicitacao> {
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
}
