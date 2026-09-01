import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { UsersService } from '../users/users.service';
import type {
  RequisicaoComUsuario,
} from './requisicao-com-usuario';
import { SupabaseAuthService } from './supabase-auth.service';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly supabaseAuthService: SupabaseAuthService,
    private readonly usersService: UsersService,
  ) {}

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

    const usuarioSupabase =
      await this.supabaseAuthService.buscarUsuario(token);

    if (!usuarioSupabase) {
      throw new UnauthorizedException('Token inválido ou expirado');
    }

    const usuario = await this.usersService.buscarPorAuthId(
      usuarioSupabase.authId,
    );

    if (!usuario) {
      throw new UnauthorizedException('Usuário não encontrado');
    }

    request.usuario = {
      sub: usuario.idUsuario,
      email: usuario.email,
      nome: usuario.nome,
    };

    return true;
  }
}
