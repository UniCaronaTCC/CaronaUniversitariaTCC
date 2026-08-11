import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

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
    private readonly usersService: UsersService,
  ) {}

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
}
