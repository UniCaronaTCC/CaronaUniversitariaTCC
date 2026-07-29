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

  async buscarPorEmail(email: string): Promise<User | null> {
    // Busca um usuário pelo e-mail
    return this.usersRepository.findOne({
      where: { email }, // Procura na coluna email
    });
  }

  async buscarPorId(idUsuario: number): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { idUsuario },
    });
  }

  async atualizarPerfil(
    idUsuario: number,
    instituicao: string,
    campus: string | null,
  ): Promise<User | null> {
    const usuario = await this.buscarPorId(idUsuario);

    if (!usuario) {
      return null;
    }

    usuario.instituicao = instituicao;
    usuario.campus = campus;

    return this.usersRepository.save(usuario);
  }

  // Busca as credenciais apenas durante a autenticação.
  async buscarPorEmailComSenha(email: string): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder('usuario')
      .addSelect('usuario.senha')
      .where('usuario.email = :email', { email })
      .getOne();
  }

  async criarUsuario(
    nome: string,
    email: string,
    senha: string,
  ): Promise<User> {
    // cria um novo usuario no banco

    const novoUsuario = this.usersRepository.create({
      nome,
      email,
      senha,
    });
    // monta o objeto do novo usuario

    return this.usersRepository.save(novoUsuario);
    // salva no banco e retorna o usuario criado
  }
}
