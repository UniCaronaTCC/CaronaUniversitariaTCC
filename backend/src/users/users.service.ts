import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { InstituicoesService } from '../instituicoes/instituicoes.service';
import { User } from './user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    private readonly instituicoesService: InstituicoesService,
  ) {}

  async buscarPorEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { email },
    });
  }

  async buscarPorId(idUsuario: number): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { idUsuario },
    });
  }

  async buscarPorEmailComSenha(
    email: string,
  ): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder('usuario')
      .addSelect('usuario.senha')
      .where('usuario.email = :email', { email })
      .getOne();
  }

  // Busca o usuário incluindo os campos usados na confirmação de e-mail.
  async buscarPorEmailComVerificacao(
    email: string,
  ): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder('usuario')
      .addSelect('usuario.codigoVerificacaoEmail')
      .addSelect('usuario.codigoVerificacaoEmailExpiraEm')
      .addSelect('usuario.codigoVerificacaoEmailEnviadoEm')
      .where('usuario.email = :email', { email })
      .getOne();
  }

  async salvarUsuario(
    usuario: User,
  ): Promise<User> {
    return this.usersRepository.save(usuario);
  }

  async atualizarPerfil(
    idUsuario: number,
    idInstituicao: number,
    campus: string | null,
  ): Promise<User | null> {
    const usuario = await this.buscarPorId(idUsuario);

    if (!usuario) {
      return null;
    }

    const instituicao =
      await this.instituicoesService.buscarPorId(idInstituicao);

    if (!instituicao) {
      throw new BadRequestException('Instituição inválida');
    }

    if (
      !campus ||
      !(await this.instituicoesService.campusValido(
        idInstituicao,
        campus,
      ))
    ) {
      throw new BadRequestException('Campus inválido');
    }

    usuario.idInstituicao =
      instituicao.idInstituicao;

    usuario.instituicao =
      instituicao.nome;

    usuario.campus =
      campus;

    return this.usersRepository.save(usuario);
  }

  async atualizarFotoPerfil(
    usuario: User,
    fotoPerfil: string,
  ): Promise<User> {
    usuario.fotoPerfil = fotoPerfil;

    return this.usersRepository.save(usuario);
  }

  async criarUsuario(
    nome: string,
    email: string,
    senha: string,
  ): Promise<User> {
    const novoUsuario =
      this.usersRepository.create({
        nome,
        email,
        senha,
      });

    return this.usersRepository.save(
      novoUsuario,
    );
  }
}