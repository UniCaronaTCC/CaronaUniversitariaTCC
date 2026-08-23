import {
  BadRequestException,
  Injectable,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';

import { UsersService } from '../users/users.service';
import { EmailService } from './email.service';

@Injectable()
export class EmailVerificacaoService {
  private readonly tempoExpiracaoMinutos = 10;
  private readonly tempoReenvioSegundos = 60;

  constructor(
    private readonly usersService: UsersService,
    private readonly emailService: EmailService,
  ) {}

  async enviarCodigo(email: string): Promise<void> {
    const emailNormalizado = email.trim().toLowerCase();

    const usuario =
      await this.usersService.buscarPorEmailComVerificacao(
        emailNormalizado,
      );

    if (!usuario) {
      throw new BadRequestException(
        'Usuário não encontrado',
      );
    }

    if (usuario.emailVerificado) {
      throw new BadRequestException(
        'E-mail já confirmado',
      );
    }

    this.validarTempoReenvio(
      usuario.codigoVerificacaoEmailEnviadoEm,
    );

    const codigo = this.gerarCodigo();

    usuario.codigoVerificacaoEmail =
      await bcrypt.hash(codigo, 10);

    usuario.codigoVerificacaoEmailEnviadoEm =
      new Date();

    usuario.codigoVerificacaoEmailExpiraEm =
      new Date(
        Date.now() +
          this.tempoExpiracaoMinutos * 60 * 1000,
      );

    await this.usersService.salvarUsuario(
      usuario,
    );

    await this.emailService.enviarCodigoVerificacao(
      usuario.email,
      usuario.nome,
      codigo,
    );
  }

  async confirmarCodigo(
    email: string,
    codigo: string,
  ): Promise<void> {
    const emailNormalizado =
      email.trim().toLowerCase();

    const codigoNormalizado =
      codigo.trim();

    if (!/^\d{6}$/.test(codigoNormalizado)) {
      throw new BadRequestException(
        'Código de verificação inválido',
      );
    }

    const usuario =
      await this.usersService.buscarPorEmailComVerificacao(
        emailNormalizado,
      );

    if (!usuario) {
      throw new BadRequestException(
        'Código de verificação inválido',
      );
    }

    if (usuario.emailVerificado) {
      return;
    }

    if (
      !usuario.codigoVerificacaoEmail ||
      !usuario.codigoVerificacaoEmailExpiraEm
    ) {
      throw new BadRequestException(
        'Solicite um novo código de verificação',
      );
    }

    if (
      usuario.codigoVerificacaoEmailExpiraEm.getTime() <
      Date.now()
    ) {
      throw new BadRequestException(
        'Código expirado. Solicite um novo código.',
      );
    }

    const codigoCorreto = await bcrypt.compare(
      codigoNormalizado,
      usuario.codigoVerificacaoEmail,
    );

    if (!codigoCorreto) {
      throw new BadRequestException(
        'Código de verificação inválido',
      );
    }

    usuario.emailVerificado = true;
    usuario.codigoVerificacaoEmail = null;
    usuario.codigoVerificacaoEmailExpiraEm = null;
    usuario.codigoVerificacaoEmailEnviadoEm = null;

    await this.usersService.salvarUsuario(
      usuario,
    );
  }

  private validarTempoReenvio(
    ultimoEnvio: Date | null,
  ): void {
    if (!ultimoEnvio) {
      return;
    }

    const segundosPassados = Math.floor(
      (Date.now() - ultimoEnvio.getTime()) / 1000,
    );

    if (
      segundosPassados >=
      this.tempoReenvioSegundos
    ) {
      return;
    }

    const restantes =
      this.tempoReenvioSegundos -
      segundosPassados;

    throw new BadRequestException(
      `Aguarde ${restantes} segundos para reenviar o código`,
    );
  }

  private gerarCodigo(): string {
    return Math.floor(
      100000 + Math.random() * 900000,
    ).toString();
  }
}