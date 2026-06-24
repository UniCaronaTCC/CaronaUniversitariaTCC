import { Injectable } from '@nestjs/common';
// Importa o Injectable para permitir que o service seja usado pelo NestJS

import { InjectRepository } from '@nestjs/typeorm';
// Permite injetar o repositório da tabela

import { Repository } from 'typeorm';
// Importa o tipo Repository do TypeORM

import { Carona } from './carona.entity';
// Importa a entidade que representa a tabela caronas

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
    // Injeta o repositório da entidade Carona

    private readonly caronasRepository: Repository<Carona>,
    // Cria o acesso à tabela caronas
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
    diasSemana: string[] | null,
    observacoes?: string,
  ): Promise<Carona> {
    // Define se os dados de recorrência realmente devem ser salvos
    const possuiRecorrencia = recorrente === true;

    // Monta o objeto da nova oferta de carona
    const novaCarona = this.caronasRepository.create({
      origem,
      destino,
      dataInicio,

      // Só guarda uma data final quando a carona for recorrente
      dataFim: possuiRecorrencia ? dataFim : null,

      horario,
      vagas,
      valor,
      recorrente: possuiRecorrencia,

      // Só guarda os dias da semana quando houver recorrência
      diasSemana: possuiRecorrencia ? diasSemana : null,

      // Converte observação vazia ou inexistente para null
      observacoes: observacoes ?? null,

      status: 'ATIVA',
    });

    // Salva a carona no banco e retorna o registro criado
    return this.caronasRepository.save(novaCarona);
  }

  async listarCaronas(): Promise<Carona[]> {
    // Retorna primeiro as caronas criadas mais recentemente
    return this.caronasRepository.find({
      order: {
        criadoEm: 'DESC',
      },
    });
  }
}