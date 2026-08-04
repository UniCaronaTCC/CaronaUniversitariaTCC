import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type {
  RequisicaoComUsuario,
  UsuarioToken,
} from './requisicao-com-usuario';

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
      const payload = await this.jwtService.verifyAsync<UsuarioToken>(token);

      if (
        !Number.isInteger(payload.sub) ||
        typeof payload.email !== 'string' ||
        typeof payload.nome !== 'string'
      ) {
        throw new UnauthorizedException('Token inválido');
      }

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
