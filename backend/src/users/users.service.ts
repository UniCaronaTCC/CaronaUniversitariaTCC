import { Injectable } from '@nestjs/common'; // Importa o Injectable para permitir que o service seja usado pelo NestJS
import { InjectRepository } from '@nestjs/typeorm'; // Permite injetar o repositório da tabela
import { Repository } from 'typeorm'; // Importa o tipo Repository do TypeORM

import { User } from './user.entity'; // Importa a entidade User, que representa a tabela usuarios

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) // Injeta o repositório da entidade User
    private readonly usersRepository: Repository<User>, // Cria o acesso à tabela usuarios
  ) {}

  async buscarPorEmail(email: string): Promise<User | null> { // Busca um usuário pelo e-mail
    return this.usersRepository.findOne({
      where: { email }, // Procura na coluna email
    });
  }
}