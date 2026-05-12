import { Module } from '@nestjs/common'; // Importa o módulo principal do NestJS

import { UsersModule } from '../users/users.module'; // Importa o módulo de usuários para o login conseguir consultar usuários
import { AuthController } from './auth.controller'; // Importa o controller de autenticação
import { AuthService } from './auth.service'; // Importa o service de autenticação

@Module({
  imports: [UsersModule], // Permite que o AuthService use o UsersService
  controllers: [AuthController], // Registra as rotas de autenticação
  providers: [AuthService], // Registra a lógica de autenticação
})
export class AuthModule {}