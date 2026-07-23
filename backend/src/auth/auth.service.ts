import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

import { UsersService } from '../users/users.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  async login(email: string, senha: string) {
    const usuario = await this.usersService.buscarPorEmailComSenha(email);

    if (!usuario) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    const senhaCorreta = await bcrypt.compare(senha, usuario.senha);

    if (!senhaCorreta) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    const payload = {
      sub: usuario.idUsuario,
      email: usuario.email,
      nome: usuario.nome,
    };
    const token = await this.jwtService.signAsync(payload);

    return {
      mensagem: 'Login realizado com sucesso',
      token,
      usuario: {
        id: usuario.idUsuario,
        nome: usuario.nome,
        email: usuario.email,
      },
    };
  }

  async cadastro(nome: string, email: string, senha: string) {
    const usuarioExistente = await this.usersService.buscarPorEmail(email);

    if (usuarioExistente) {
      throw new ConflictException('E-mail já cadastrado');
    }

    const senhaHash = await bcrypt.hash(senha, 10);
    const novoUsuario = await this.usersService.criarUsuario(
      nome,
      email,
      senhaHash,
    );

    return {
      mensagem: 'Cadastro realizado com sucesso',
      usuario: {
        id: novoUsuario.idUsuario,
        nome: novoUsuario.nome,
        email: novoUsuario.email,
      },
    };
  }
}
