import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { User } from './user.entity';
import { UsersService } from './users.service';

type DadosPerfilRecebidos = Record<string, unknown> | undefined;

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
      dados: this.formatarPerfil(usuario),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Patch('perfil')
  async atualizarPerfil(
    @Body() body: DadosPerfilRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const instituicao = body?.instituicao?.toString().trim() ?? '';
    const campusRecebido = body?.campus?.toString().trim() ?? '';

    if (instituicao.length < 2 || instituicao.length > 150) {
      throw new BadRequestException('Instituição inválida');
    }

    if (campusRecebido.length > 150) {
      throw new BadRequestException('Campus inválido');
    }

    const usuario = await this.usersService.atualizarPerfil(
      request.usuario.sub,
      instituicao,
      campusRecebido || null,
    );

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    return {
      sucesso: true,
      mensagem: 'Perfil atualizado com sucesso',
      dados: this.formatarPerfil(usuario),
    };
  }

  private formatarPerfil(usuario: User) {
    return {
      id: usuario.idUsuario,
      nome: usuario.nome,
      email: usuario.email,
      instituicao: usuario.instituicao,
      campus: usuario.campus,
      tipoPerfil: usuario.tipoPerfil,
      statusVerificacao: usuario.statusVerificacao,
    };
  }
}
