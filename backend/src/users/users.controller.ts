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
    const idInstituicao = Number(body?.idInstituicao);
    const campusRecebido = body?.campus?.toString().trim() ?? '';

    if (!Number.isInteger(idInstituicao) || idInstituicao <= 0) {
      throw new BadRequestException('Instituição inválida');
    }

    if (campusRecebido.length === 0 || campusRecebido.length > 150) {
      throw new BadRequestException('Campus inválido');
    }

    const usuario = await this.usersService.atualizarPerfil(
      request.usuario.sub,
      idInstituicao,
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
      idInstituicao: usuario.idInstituicao,
      instituicao: usuario.instituicao,
      campus: usuario.campus,
      tipoPerfil: usuario.tipoPerfil,
      tipoPerfilSolicitado: usuario.tipoPerfilSolicitado,
      statusVerificacao: usuario.statusVerificacao,
    };
  }
}
