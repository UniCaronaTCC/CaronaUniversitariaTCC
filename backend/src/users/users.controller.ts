import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Patch,
  Put,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { FotoPerfilService } from './foto-perfil.service';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { Veiculo } from './veiculo.entity';

type DadosPerfilRecebidos = Record<string, unknown> | undefined;

interface FotoRecebida {
  buffer: Buffer;
}

@Controller('usuarios')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly fotoPerfilService: FotoPerfilService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Get('perfil')
  async buscarPerfil(@Req() request: RequisicaoComUsuario) {
    const usuario = await this.usersService.buscarPorId(request.usuario.sub);

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    const veiculo = await this.usersService.buscarVeiculo(usuario.idUsuario);

    return {
      sucesso: true,
      dados: this.formatarPerfil(usuario, veiculo),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Put('perfil/veiculo')
  async salvarVeiculo(
    @Body() body: DadosPerfilRecebidos,
    @Req() request: RequisicaoComUsuario,
  ) {
    const modelo = body?.modelo?.toString().trim() ?? '';
    const cor = body?.cor?.toString().trim() ?? '';
    const placa = (body?.placa?.toString() ?? '')
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '');

    if (modelo.length < 2 || modelo.length > 100) {
      throw new BadRequestException('Informe um modelo válido');
    }

    if (cor.length < 2 || cor.length > 50) {
      throw new BadRequestException('Informe uma cor válida');
    }

    if (!/^[A-Z]{3}(?:\d{4}|\d[A-Z]\d{2})$/.test(placa)) {
      throw new BadRequestException('Informe uma placa válida');
    }

    const usuario = await this.usersService.buscarPorId(request.usuario.sub);

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    const veiculo = await this.usersService.salvarVeiculo(
      usuario.idUsuario,
      modelo,
      cor,
      placa,
    );

    return {
      sucesso: true,
      mensagem: 'Veículo salvo com sucesso',
      dados: this.formatarVeiculo(veiculo),
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

    const veiculo = await this.usersService.buscarVeiculo(usuario.idUsuario);

    return {
      sucesso: true,
      mensagem: 'Perfil atualizado com sucesso',
      dados: this.formatarPerfil(usuario, veiculo),
    };
  }

  @UseGuards(JwtAuthGuard)
  @Patch('perfil/foto')
  @UseInterceptors(
    FileInterceptor('foto', {
      limits: {
        files: 1,
        fileSize: 5 * 1024 * 1024,
      },
    }),
  )
  async atualizarFotoPerfil(
    @UploadedFile() foto: FotoRecebida | undefined,
    @Req() request: RequisicaoComUsuario,
  ) {
    if (!foto?.buffer.length) {
      throw new BadRequestException('Selecione uma foto');
    }

    const tipoArquivo = this.identificarTipoImagem(foto.buffer);

    if (!tipoArquivo) {
      throw new BadRequestException('Envie uma imagem JPG, PNG ou WebP');
    }

    const usuario = await this.usersService.buscarPorId(request.usuario.sub);

    if (!usuario) {
      throw new NotFoundException('Usuário não encontrado');
    }

    const url = await this.fotoPerfilService.enviar(
      usuario.idUsuario,
      foto.buffer,
      tipoArquivo,
    );
    const usuarioAtualizado = await this.usersService.atualizarFotoPerfil(
      usuario,
      url,
    );
    const veiculo = await this.usersService.buscarVeiculo(usuario.idUsuario);

    return {
      sucesso: true,
      mensagem: 'Foto de perfil atualizada',
      dados: this.formatarPerfil(usuarioAtualizado, veiculo),
    };
  }

  private formatarPerfil(usuario: User, veiculo: Veiculo | null = null) {
    return {
      id: usuario.idUsuario,
      nome: usuario.nome,
      email: usuario.email,
      idInstituicao: usuario.idInstituicao,
      instituicao: usuario.instituicao,
      campus: usuario.campus,
      fotoPerfil: usuario.fotoPerfil,
      tipoPerfil: usuario.tipoPerfil,
      tipoPerfilSolicitado: usuario.tipoPerfilSolicitado,
      statusVerificacao: usuario.statusVerificacao,
      veiculo: veiculo ? this.formatarVeiculo(veiculo) : null,
    };
  }

  private formatarVeiculo(veiculo: Veiculo) {
    return {
      id: veiculo.idVeiculo,
      modelo: veiculo.modelo,
      cor: veiculo.cor,
      placa: veiculo.placa,
    };
  }

  private identificarTipoImagem(arquivo: Buffer): string | null {
    const jpeg =
      arquivo.length >= 3 &&
      arquivo[0] === 0xff &&
      arquivo[1] === 0xd8 &&
      arquivo[2] === 0xff;

    if (jpeg) {
      return 'image/jpeg';
    }

    const png =
      arquivo.length >= 8 &&
      arquivo
        .subarray(0, 8)
        .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));

    if (png) {
      return 'image/png';
    }

    const webp =
      arquivo.length >= 12 &&
      arquivo.subarray(0, 4).toString() === 'RIFF' &&
      arquivo.subarray(8, 12).toString() === 'WEBP';

    return webp ? 'image/webp' : null;
  }
}
