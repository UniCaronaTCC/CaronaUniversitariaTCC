<<<<<<< HEAD
import { Injectable } from '@nestjs/common'; // Permite que o service seja usado pelo NestJS
import { InjectRepository } from '@nestjs/typeorm'; // Permite injetar o repositório da entidade
import { Repository } from 'typeorm'; // Tipo usado para acessar o banco

import { Carona } from './carona.entity'; // Entidade que representa a tabela caronas
=======
import { Injectable } from '@nestjs/common';
// Importa o Injectable para permitir que o service seja usado pelo NestJS

import { InjectRepository } from '@nestjs/typeorm';
// Permite injetar o repositório da tabela

import { Repository } from 'typeorm';
// Importa o tipo Repository do TypeORM

import { Carona } from './carona.entity';
// Importa a entidade que representa a tabela caronas
>>>>>>> a4cf7b5db936e7a530fc9aba9114d3f7b7456c1a

@Injectable()
export class CaronasService {
  constructor(
    @InjectRepository(Carona)
<<<<<<< HEAD
    private readonly caronasRepository: Repository<Carona>,
=======
    // Injeta o repositório da entidade Carona

    private readonly caronasRepository: Repository<Carona>,
    // Cria o acesso à tabela caronas
>>>>>>> a4cf7b5db936e7a530fc9aba9114d3f7b7456c1a
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
<<<<<<< HEAD
    diasSemana?: string[],
    observacoes?: string,
  ): Promise<Carona> { // Cria uma oferta de carona no banco
=======
    diasSemana: string[] | null,
    observacoes?: string,
  ): Promise<Carona> {
    // Define se os dados de recorrência realmente devem ser salvos
    const possuiRecorrencia = recorrente === true;
>>>>>>> a4cf7b5db936e7a530fc9aba9114d3f7b7456c1a

    // Monta o objeto da nova oferta de carona
    const novaCarona = this.caronasRepository.create({
      origem,
      destino,
      dataInicio,
<<<<<<< HEAD
      dataFim,
      horario,
      vagas,
      valor,
      recorrente,
      diasSemana,
      observacoes,
=======

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

>>>>>>> a4cf7b5db936e7a530fc9aba9114d3f7b7456c1a
      status: 'ATIVA',
    });

    // Salva a carona no banco e retorna o registro criado
    return this.caronasRepository.save(novaCarona);
  }

<<<<<<< HEAD
  async listarCaronas(): Promise<Carona[]> { // Lista as caronas mais recentes
=======
  async listarCaronas(): Promise<Carona[]> {
    // Retorna primeiro as caronas criadas mais recentemente
>>>>>>> a4cf7b5db936e7a530fc9aba9114d3f7b7456c1a
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