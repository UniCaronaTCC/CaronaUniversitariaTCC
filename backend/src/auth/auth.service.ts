import {
  BadRequestException,
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
    const emailNormalizado = email.trim().toLowerCase();
    const usuario =
      await this.usersService.buscarPorEmailComSenha(emailNormalizado);

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
        instituicao: usuario.instituicao,
        campus: usuario.campus,
        tipoPerfil: usuario.tipoPerfil,
        statusVerificacao: usuario.statusVerificacao,
      },
    };
  }

  async cadastro(nome: string, email: string, senha: string) {
    const nomeNormalizado = nome?.trim() ?? '';
    const emailNormalizado = email?.trim().toLowerCase() ?? '';
    const emailValido = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailNormalizado);

    if (nomeNormalizado.length < 2 || nomeNormalizado.length > 100) {
      throw new BadRequestException('Informe um nome válido');
    }

    if (!emailValido) {
      throw new BadRequestException('Informe um e-mail válido');
    }

    const temLetra = /[A-Za-zÀ-ÖØ-öø-ÿ]/.test(senha);
    const temNumero = /[0-9]/.test(senha);

    if (senha.length < 8 || !temLetra || !temNumero) {
      throw new BadRequestException(
        'A senha deve ter pelo menos 8 caracteres, com letras e números',
      );
    }

    const usuarioExistente =
      await this.usersService.buscarPorEmail(emailNormalizado);

    if (usuarioExistente) {
      throw new ConflictException('E-mail já cadastrado');
    }

    const senhaHash = await bcrypt.hash(senha, 10);
    const novoUsuario = await this.usersService.criarUsuario(
      nomeNormalizado,
      emailNormalizado,
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
