import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UsersService } from './users.service';

describe('UsersService', () => {
  let service: UsersService;
  let repository: {
    findOne: jest.Mock;
    createQueryBuilder: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };

  beforeEach(async () => {
    const queryBuilder = {
      addSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getOne: jest.fn(),
    };

    repository = {
      findOne: jest.fn(),
      createQueryBuilder: jest.fn().mockReturnValue(queryBuilder),
      create: jest.fn(),
      save: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: repository,
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('seleciona o hash somente na busca de credenciais', async () => {
    await service.buscarPorEmailComSenha('joao@email.com');

    expect(repository.createQueryBuilder).toHaveBeenCalledWith('usuario');
  });

  it('busca o perfil pelo id sem selecionar a senha', async () => {
    repository.findOne.mockResolvedValue({ idUsuario: 1 });

    await service.buscarPorId(1);

    expect(repository.findOne).toHaveBeenCalledWith({
      where: { idUsuario: 1 },
    });
  });
});
