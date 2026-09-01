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

  async buscarPorId(idUsuario: number): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { idUsuario },
    });
  }

  async buscarPorAuthId(authId: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { authId },
    });
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

}
