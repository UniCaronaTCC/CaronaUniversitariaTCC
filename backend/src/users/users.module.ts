import { Module } from '@nestjs/common'; // Importa o módulo principal do NestJS
import { TypeOrmModule } from '@nestjs/typeorm'; // Permite usar o TypeORM dentro deste módulo

import { User } from './user.entity'; // Importa a entidade que representa a tabela usuarios
import { UsersService } from './users.service'; // Importa o service de usuários

@Module({
  imports: [
    TypeOrmModule.forFeature([User]), // Registra a entidade User para este módulo usar a tabela usuarios
  ],
  providers: [UsersService], // Registra o service de usuários
  exports: [UsersService], // Permite que outros módulos, como auth, usem o UsersService
})
export class UsersModule {}