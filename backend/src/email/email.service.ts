import {
  Injectable,
  InternalServerErrorException,
} from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend: Resend;

  constructor() {
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      throw new Error(
        'RESEND_API_KEY não configurada no ambiente',
      );
    }

    this.resend = new Resend(apiKey);
  }

  async enviarEmailTeste(emailDestino: string) {
    const { data, error } = await this.resend.emails.send({
      from: 'UniCarona <onboarding@resend.dev>',
      to: [emailDestino],
      subject: 'Teste de e-mail - UniCarona',
      html: `
        <h1>UniCarona</h1>

        <p>Olá!</p>

        <p>
          Este é um e-mail de teste enviado pelo sistema
          <strong>UniCarona</strong>.
        </p>

        <p>
          Se você recebeu esta mensagem, a integração
          com o serviço de e-mail está funcionando.
        </p>

        <p>
          <strong>UniCarona</strong>
        </p>
      `,
    });

    if (error) {
      console.error('Erro ao enviar e-mail:', error);

      throw new InternalServerErrorException(
        'Não foi possível enviar o e-mail',
      );
    }

    return {
      sucesso: true,
      id: data?.id,
      mensagem: 'E-mail enviado com sucesso',
    };
  }

  async enviarCodigoVerificacao(
    emailDestino: string,
    nomeUsuario: string,
    codigo: string,
  ): Promise<void> {
    const { error } = await this.resend.emails.send({
      from: 'UniCarona <onboarding@resend.dev>',
      to: [emailDestino],
      subject: 'Confirme seu e-mail - UniCarona',
      html: `
        <div
          style="
            font-family: Arial, sans-serif;
            max-width: 520px;
            margin: 0 auto;
            color: #222;
          "
        >
          <h1>UniCarona</h1>

          <p>Olá, ${this.escaparHtml(nomeUsuario)}!</p>

          <p>
            Use o código abaixo para confirmar seu
            endereço de e-mail:
          </p>

          <div
            style="
              font-size: 32px;
              font-weight: bold;
              letter-spacing: 8px;
              margin: 28px 0;
            "
          >
            ${this.escaparHtml(codigo)}
          </div>

          <p>
            Este código é válido por
            <strong>10 minutos</strong>.
          </p>

          <p>
            Se você não criou uma conta no UniCarona,
            ignore esta mensagem.
          </p>

          <p>
            <strong>UniCarona</strong>
          </p>
        </div>
      `,
    });

    if (error) {
      console.error(
        'Erro ao enviar código de verificação:',
        error,
      );

      throw new InternalServerErrorException(
        'Não foi possível enviar o código de verificação',
      );
    }
  }

  private escaparHtml(texto: string): string {
    return texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }
}