import { Injectable } from '@nestjs/common'; // Importa o Injectable para permitir que o service seja usado pelo NestJS
import { InjectRepository } from '@nestjs/typeorm'; // Permite injetar o repositório da tabela
import { Repository } from 'typeorm'; // Importa o tipo Repository do TypeORM

import { Carona } from './carona.entity'; // Importa a entidade Carona, que representa a tabela caronas

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona) // Injeta o repositório da entidade Carona
    private readonly caronasRepository: Repository<Carona>, // Cria o acesso à tabela caronas
  ) {}

  async solicitarCarona(
    tipo: string,
    origem: string,
    destino: string,
    data: string,
    horario: string,
    observacoes?: string,
  ): Promise<Carona> { // Cria uma nova solicitação de carona no banco

    const novaCarona = this.caronasRepository.create({
      tipo,
      origem,
      destino,
      data,
      horario,
      observacoes,
      status: 'ATIVA',
    });
    // monta o objeto da nova carona

    return this.caronasRepository.save(novaCarona);
    // salva no banco e retorna a carona criada
  }

  async listarCaronas(): Promise<Carona[]> { // Lista todas as caronas cadastradas
    return this.caronasRepository.find({
      order: {
        criadoEm: 'DESC',
      },
    });
  }
}