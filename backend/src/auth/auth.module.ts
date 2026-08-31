import { Module } from '@nestjs/common';
import {
  ConfigModule,
  ConfigService,
} from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';

import { EmailModule } from '../email/email.module';
import { UsersModule } from '../users/users.module';
import { UsersController } from '../users/users.controller';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { SupabaseAuthService } from './supabase-auth.service';

@Module({
  imports: [
    UsersModule,
    EmailModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (
        configService: ConfigService,
      ) => ({
        secret:
          configService.get<string>(
            'JWT_SECRET',
          ),
        signOptions: {
          expiresIn: '7d',
        },
      }),
    }),
  ],
  controllers: [
    AuthController,
    UsersController,
  ],
  providers: [
    AuthService,
    JwtAuthGuard,
    SupabaseAuthService,
  ],
  exports: [
    JwtAuthGuard,
    JwtModule,
    SupabaseAuthService,
    UsersModule,
  ],
})
export class AuthModule {}
