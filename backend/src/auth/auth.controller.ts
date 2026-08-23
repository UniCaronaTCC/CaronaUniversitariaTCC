import {
  BadRequestException,
  Body,
  Controller,
  Post,
} from '@nestjs/common';

import { AuthService } from './auth.service';

type DadosAuthRecebidos =
  | Record<string, unknown>
  | undefined;

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
  ) {}

  @Post('login')
  login(
    @Body() body: DadosAuthRecebidos,
  ) {
    const email =
      body?.email?.toString().trim() ?? '';

    const senha =
      body?.senha?.toString() ?? '';

    if (!email || !senha) {
      throw new BadRequestException(
        'E-mail e senha são obrigatórios',
      );
    }

    return this.authService.login(
      email,
      senha,
    );
  }

  @Post('cadastro')
  cadastro(
    @Body() body: DadosAuthRecebidos,
  ) {
    const nome =
      body?.nome?.toString().trim() ?? '';

    const email =
      body?.email?.toString().trim() ?? '';

    const senha =
      body?.senha?.toString() ?? '';

    if (!nome || !email || !senha) {
      throw new BadRequestException(
        'Nome, e-mail e senha são obrigatórios',
      );
    }

    return this.authService.cadastro(
      nome,
      email,
      senha,
    );
  }

  @Post('confirmar-email')
  confirmarEmail(
    @Body() body: DadosAuthRecebidos,
  ) {
    const email =
      body?.email?.toString().trim() ?? '';

    const codigo =
      body?.codigo?.toString().trim() ?? '';

    if (!email || !codigo) {
      throw new BadRequestException(
        'E-mail e código são obrigatórios',
      );
    }

    return this.authService.confirmarEmail(
      email,
      codigo,
    );
  }

  @Post('reenviar-codigo')
  reenviarCodigo(
    @Body() body: DadosAuthRecebidos,
  ) {
    const email =
      body?.email?.toString().trim() ?? '';

    if (!email) {
      throw new BadRequestException(
        'E-mail é obrigatório',
      );
    }

    return this.authService.reenviarCodigoVerificacao(
      email,
    );
  }
}