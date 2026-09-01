import { Module } from '@nestjs/common';

import { UsersModule } from '../users/users.module';
import { UsersController } from '../users/users.controller';
import { JwtAuthGuard } from './jwt-auth.guard';
import { SupabaseAuthService } from './supabase-auth.service';

@Module({
  imports: [UsersModule],
  controllers: [UsersController],
  providers: [JwtAuthGuard, SupabaseAuthService],
  exports: [
    JwtAuthGuard,
    SupabaseAuthService,
    UsersModule,
  ],
})
export class AuthModule {}
