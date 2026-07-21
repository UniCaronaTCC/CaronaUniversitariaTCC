import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
// Importa recursos do NestJS para criar serviços e lançar erros HTTP

import { JwtService } from '@nestjs/jwt';
// Importa o serviço responsável por gerar tokens JWT

import * as bcrypt from 'bcrypt';
// Importa o bcrypt, usado para gerar hash da senha e comparar senha no login

import { UsersService } from '../users/users.service';
// Importa o service de usuários para buscar e criar usuários no banco

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    // Permite usar funções do UsersService dentro do AuthService

    private readonly jwtService: JwtService,
    // Permite gerar tokens JWT dentro do AuthService
  ) {}

  // FUNÇÃO DE LOGIN
  async login(email: string, senha: string) {
    // Busca o usuário pelo e-mail informado
    const usuario = await this.usersService.buscarPorEmailComSenha(email);

    // Verifica se o usuário existe
    if (!usuario) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    // Compara a senha digitada com o hash salvo no banco
    const senhaCorreta = await bcrypt.compare(senha, usuario.senha);

    // Se a senha estiver errada, retorna erro de login
    if (!senhaCorreta) {
      throw new UnauthorizedException('E-mail ou senha inválidos');
    }

    // Define os dados que serão guardados dentro do token
    const payload = {
      sub: usuario.idUsuario,
      email: usuario.email,
      nome: usuario.nome,
    };

    // Gera o token JWT usando o payload acima
    const token = await this.jwtService.signAsync(payload);

    // Retorna sucesso sem enviar a senha para o frontend
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

  // FUNÇÃO DE CADASTRO
  async cadastro(nome: string, email: string, senha: string) {
    // Verifica se já existe usuário com esse e-mail
    const usuarioExistente = await this.usersService.buscarPorEmail(email);

    // Se existir, retorna erro de conflito
    if (usuarioExistente) {
      throw new ConflictException('E-mail já cadastrado');
    }

    // Gera o hash da senha antes de salvar no banco
    // O número 10 é o custo do hash: bom equilíbrio para projeto acadêmico
    const senhaHash = await bcrypt.hash(senha, 10);

    // Cria usuário no banco usando a senha em hash, não a senha original
    const novoUsuario = await this.usersService.criarUsuario(
      nome,
      email,
      senhaHash,
    );

    // Retorna sucesso sem enviar a senha para o frontend
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
