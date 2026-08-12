import { Controller, Post, Body } from '@nestjs/common';
import { EmailService } from './email.service';

@Controller('email')
export class EmailController {
  constructor(private readonly emailService: EmailService) {}

  @Post('teste')
  async enviarEmailTeste(
    @Body('email') email: string,
  ) {
    return this.emailService.enviarEmailTeste(email);
  }
}