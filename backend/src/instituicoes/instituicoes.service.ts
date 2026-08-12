import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Like, Repository } from 'typeorm';

import { Instituicao } from './instituicao.entity';

@Injectable()
export class InstituicoesService {
  constructor(
    @InjectRepository(Instituicao)
    private readonly instituicoesRepository: Repository<Instituicao>,
  ) {}

  async buscar(termo: string): Promise<Instituicao[]> {
    const busca = termo.replace(/[%_]/g, '').trim();

    if (busca.length < 2) {
      return [];
    }

    return this.instituicoesRepository.find({
      where: [
        { nome: Like(`%${busca}%`), ativa: true },
        { sigla: Like(`%${busca}%`), ativa: true },
      ],
      order: {
        nome: 'ASC',
        municipio: 'ASC',
      },
      take: 10,
    });
  }
}
