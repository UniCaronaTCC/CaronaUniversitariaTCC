import {
  Controller,
  Get,
  NotFoundException,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';

import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UsersService } from './users.service';

interface RequisicaoComUsuario extends Request {
  usuario: {
    sub: number;
    email: string;
    nome: string;
  };
}

@Controller('usuarios')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Get('perfil')
  async buscarPerfil(@Req() request: RequisicaoComUsuario) {
    const usuario = await this.usersService.buscarPorId(request.usuario.sub);

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    return {
      sucesso: true,
      dados: {
        id: usuario.idUsuario,
        nome: usuario.nome,
        email: usuario.email,
        instituicao: usuario.instituicao,
        campus: usuario.campus,
      },
    };
  }
}
