import { Module } from '@nestjs/common';

import { UsersModule } from '../users/users.module';
import { EmailVerificacaoService } from './email-verificacao.service';
import { EmailService } from './email.service';

@Module({
  imports: [UsersModule],
  providers: [
    EmailService,
    EmailVerificacaoService,
  ],
  exports: [
    EmailService,
    EmailVerificacaoService,
  ],
})
export class EmailModule {}