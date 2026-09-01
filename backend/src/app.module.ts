import { Module } from '@nestjs/common'; // Importa o módulo principal do NestJS
import { ConfigModule } from '@nestjs/config'; // Permite ler as variáveis do arquivo .env
import { TypeOrmModule } from '@nestjs/typeorm'; // Permite conectar o NestJS com o banco usando TypeORM

import { AppController } from './app.controller'; // Importa o controller principal criado pelo NestJS
import { AppService } from './app.service'; // Importa o service principal criado pelo NestJS
import { AuthModule } from './auth/auth.module'; // Importa o módulo de autenticação
import { UsersModule } from './users/users.module'; // Importa o módulo de usuários
import { AvaliacoesModule } from './avaliacoes/avaliacoes.module';
import { CaronasModule } from './caronas/caronas.module';
import { InstituicoesModule } from './instituicoes/instituicoes.module';
import { SolicitacoesModule } from './solicitacoes/solicitacoes.module';

import { RotasModule } from './rotas/rotas.module';


@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true, // Faz o .env ficar disponível para o projeto inteiro
    }),

    TypeOrmModule.forRoot({
      type: 'postgres', // Define que o banco usado será PostgreSQL
      host: process.env.DB_HOST, // Pega o endereço do banco no .env
      port: Number(process.env.DB_PORT ?? 5432), // Pega a porta do banco no .env
      username: process.env.DB_USERNAME, // Pega o usuário do banco no .env
      password: process.env.DB_PASSWORD, // Pega a senha do banco no .env
      database: process.env.DB_DATABASE, // Pega o nome do banco no .env
      schema: process.env.DB_SCHEMA ?? 'unicarona', // Usa o esquema privado do app
      ssl:
        process.env.DB_SSL === 'true'
          ? {
              rejectUnauthorized:
                process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
            }
          : false, // Mantém a conexão com o Supabase criptografada
      autoLoadEntities: true, // Carrega automaticamente as entidades criadas no projeto
      synchronize: false, // Não altera o banco automaticamente
    }),

    AuthModule, // Carrega o módulo de autenticação
    UsersModule, // Carrega o módulo de usuários
    CaronasModule,
    SolicitacoesModule,
    AvaliacoesModule,
    InstituicoesModule,
    RotasModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}