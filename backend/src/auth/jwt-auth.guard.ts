import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
// Importa recursos do NestJS para criar um guard e retornar erro 401

import { JwtService } from '@nestjs/jwt';
// Importa o serviço usado para validar o token JWT

import { Request } from 'express';
// Importa o tipo Request do Express

interface RequisicaoComUsuario extends Request {
  usuario?: {
    sub: number;
    email: string;
    nome: string;
  };
}
// Cria um tipo de requisição que pode receber os dados do usuário logado

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    // Permite validar o token recebido na requisição
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Pega a requisição HTTP atual
    const request = context.switchToHttp().getRequest<RequisicaoComUsuario>();

    // Pega o cabeçalho Authorization
    const authorization = request.headers.authorization;

    // Se não veio Authorization, bloqueia a requisição
    if (!authorization) {
      throw new UnauthorizedException('Token não informado');
    }

    // Esperado: Authorization: Bearer token_aqui
    const [tipo, token] = authorization.split(' ');

    // Verifica se o formato está correto
    if (tipo !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token em formato inválido');
    }

    try {
      // Valida o token e extrai os dados salvos nele
      const payload = await this.jwtService.verifyAsync(token);

      // Guarda os dados do usuário dentro da requisição
      request.usuario = {
        sub: payload.sub,
        email: payload.email,
        nome: payload.nome,
      };

      // Permite a requisição continuar
      return true;
    } catch {
      // Se o token for inválido ou expirado, bloqueia
      throw new UnauthorizedException('Token inválido ou expirado');
    }
  }
}