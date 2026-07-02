import { Module } from '@nestjs/common';
// Importa o módulo principal do NestJS

import { JwtModule } from '@nestjs/jwt';
// Importa o módulo responsável por gerar e validar tokens JWT

import { ConfigModule, ConfigService } from '@nestjs/config';
// Permite ler variáveis do arquivo .env

import { UsersModule } from '../users/users.module';
// Importa o módulo de usuários para o login conseguir consultar usuários

import { AuthController } from './auth.controller';
// Importa o controller de autenticação

import { AuthService } from './auth.service';
// Importa o service de autenticação

import { JwtAuthGuard } from './jwt-auth.guard';
// Importa o guard que valida o token JWT

@Module({
  imports: [
    UsersModule,
    // Permite que o AuthService use o UsersService

    JwtModule.registerAsync({
      imports: [ConfigModule],

      inject: [ConfigService],

      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),

        signOptions: {
          expiresIn: '7d',
        },
      }),
    }),
    // Configura o JWT usando a chave salva no .env
  ],

  controllers: [AuthController],
  // Registra as rotas de autenticação

  providers: [
    AuthService,
    JwtAuthGuard,
  ],
  // Registra a lógica de autenticação e o guard JWT

  exports: [
    JwtAuthGuard,
    JwtModule,
  ],
  // Permite que outros módulos usem o guard e o JWT
})
export class AuthModule {}