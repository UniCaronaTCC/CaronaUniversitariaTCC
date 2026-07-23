import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';

interface RequisicaoComUsuario extends Request {
  usuario?: {
    sub: number;
    email: string;
    nome: string;
  };
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequisicaoComUsuario>();
    const authorization = request.headers.authorization;

    if (!authorization) {
      throw new UnauthorizedException('Token não informado');
    }

    const [tipo, token] = authorization.split(' ');

    if (tipo !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token em formato inválido');
    }

    try {
      const payload = await this.jwtService.verifyAsync(token);

      request.usuario = {
        sub: payload.sub,
        email: payload.email,
        nome: payload.nome,
      };

      return true;
    } catch {
      throw new UnauthorizedException('Token inválido ou expirado');
    }
  }
}
