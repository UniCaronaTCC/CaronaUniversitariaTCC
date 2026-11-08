import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Avaliacao } from './avaliacao.entity';

export interface ResumoReputacao {
  media: number;
  total: number;
}

interface ResumoBanco {
  idUsuario: string | number;
  media: string | number;
  total: string | number;
}

@Injectable()
export class ReputacoesService {
  private readonly logger = new Logger(ReputacoesService.name);

  constructor(
    @InjectRepository(Avaliacao)
    private readonly avaliacoes: Repository<Avaliacao>,
  ) {}

  async buscarResumos(ids: number[]): Promise<Map<number, ResumoReputacao>> {
    const idsUsuarios = [...new Set(ids)].filter(
      (id) => Number.isSafeInteger(id) && id > 0,
    );
    if (!idsUsuarios.length) return new Map();

    try {
      const registros = await this.avaliacoes
        .createQueryBuilder('avaliacao')
        .select('avaliacao.id_avaliado', 'idUsuario')
        .addSelect('AVG(avaliacao.nota)', 'media')
        .addSelect('COUNT(*)', 'total')
        .where('avaliacao.id_avaliado IN (:...idsUsuarios)', { idsUsuarios })
        .groupBy('avaliacao.id_avaliado')
        .getRawMany<ResumoBanco>();

      const resumos = new Map<number, ResumoReputacao>(
        idsUsuarios.map((id) => [id, { media: 0, total: 0 }]),
      );
      for (const registro of registros) {
        const id = Number(registro.idUsuario);
        const media = Number(registro.media);
        const total = Number(registro.total);
        if (
          !resumos.has(id) ||
          !Number.isFinite(media) ||
          media < 1 ||
          media > 5 ||
          !Number.isSafeInteger(total) ||
          total < 1
        ) {
          throw new Error('Resumo de reputacao invalido');
        }
        resumos.set(id, { media: Number(media.toFixed(2)), total });
      }
      return resumos;
    } catch {
      // Uma falha no resumo nao deve impedir a consulta das caronas.
      this.logger.warn('Nao foi possivel consultar os resumos de reputacao');
      return new Map();
    }
  }
}
