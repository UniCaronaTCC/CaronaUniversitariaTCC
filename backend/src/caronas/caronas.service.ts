import { Injectable } from '@nestjs/common'; // Permite que o service seja usado pelo NestJS
import { InjectRepository } from '@nestjs/typeorm'; // Permite injetar o repositório da entidade
import { Repository } from 'typeorm'; // Tipo usado para acessar o banco

import { Carona } from './carona.entity'; // Entidade que representa a tabela caronas

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
    private readonly caronasRepository: Repository<Carona>,
  ) {}

  async criarCarona(
    origem: string,
    destino: string,
    dataInicio: string,
    dataFim: string | null,
    horario: string,
    vagas: number,
    valor: number,
    recorrente: boolean,
    diasSemana?: string[],
    observacoes?: string,
  ): Promise<Carona> { // Cria uma oferta de carona no banco

    const novaCarona = this.caronasRepository.create({
      origem,
      destino,
      dataInicio,
      dataFim,
      horario,
      vagas,
      valor,
      recorrente,
      diasSemana,
      observacoes,
      status: 'ATIVA',
    });

    return this.caronasRepository.save(novaCarona);
  }

  async listarCaronas(): Promise<Carona[]> { // Lista as caronas mais recentes
    return this.caronasRepository.find({
      where: {
        status: 'ATIVA',
      },
      order: {
        criadoEm: 'DESC',
      },
    });
  }
}