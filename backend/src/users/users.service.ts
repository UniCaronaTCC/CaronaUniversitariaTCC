import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';

import { InstituicoesService } from '../instituicoes/instituicoes.service';
import { User } from './user.entity';
import { Veiculo } from './veiculo.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
    @InjectRepository(Veiculo)
    private readonly veiculosRepository: Repository<Veiculo>,
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
      !(await this.instituicoesService.campusValido(idInstituicao, campus))
    ) {
      throw new BadRequestException('Campus inválido');
    }

    usuario.idInstituicao = instituicao.idInstituicao;

    usuario.instituicao = instituicao.nome;

    usuario.campus = campus;

    return this.usersRepository.save(usuario);
  }

  async atualizarFotoPerfil(usuario: User, fotoPerfil: string): Promise<User> {
    usuario.fotoPerfil = fotoPerfil;

    return this.usersRepository.save(usuario);
  }

  async buscarVeiculo(idUsuario: number): Promise<Veiculo | null> {
    return this.veiculosRepository.findOne({
      where: { usuario: { idUsuario } },
    });
  }

  async salvarVeiculo(
    idUsuario: number,
    modelo: string,
    cor: string,
    placa: string,
  ): Promise<Veiculo> {
    const existente = await this.buscarVeiculo(idUsuario);
    const veiculo = existente ?? this.veiculosRepository.create();

    veiculo.modelo = modelo;
    veiculo.cor = cor;
    veiculo.placa = placa;

    if (!existente) {
      veiculo.usuario = { idUsuario } as User;
    }

    try {
      return await this.veiculosRepository.save(veiculo);
    } catch (erro) {
      const codigo =
        erro instanceof QueryFailedError
          ? (erro.driverError as { code?: string } | undefined)?.code
          : undefined;

      if (codigo === '23505') {
        throw new ConflictException('Esta placa já está cadastrada');
      }

      throw erro;
    }
  }
}
