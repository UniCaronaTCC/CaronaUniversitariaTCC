import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class EmailService {
  private readonly resend: Resend;

  constructor() {
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      throw new Error('RESEND_API_KEY não configurada no ambiente');
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
}