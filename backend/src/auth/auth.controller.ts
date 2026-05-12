import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  login(@Body() dadosLogin: { email: string; senha: string }) {
    return this.authService.login(dadosLogin.email, dadosLogin.senha);
  }

  @Post('cadastro')
cadastro(@Body() dadosCadastro: { nome: string; email: string; senha: string }) {
  return this.authService.cadastro(
    dadosCadastro.nome,
    dadosCadastro.email,
    dadosCadastro.senha,
  );
}

}