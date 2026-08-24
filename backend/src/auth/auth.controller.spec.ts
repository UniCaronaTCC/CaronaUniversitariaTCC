import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            login: jest.fn(),
            cadastro: jest.fn(),
            solicitarRedefinicaoSenha: jest.fn(),
            redefinirSenha: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('recusa login sem e-mail e senha', () => {
    expect(() => controller.login(undefined)).toThrow(BadRequestException);
  });

  it('recusa recuperação sem e-mail', () => {
    expect(() => controller.esqueciSenha(undefined)).toThrow(
      BadRequestException,
    );
  });

  it('recusa redefinição sem os dados obrigatórios', () => {
    expect(() =>
      controller.redefinirSenha({ email: 'joao@email.com' }),
    ).toThrow(BadRequestException);
  });
});
