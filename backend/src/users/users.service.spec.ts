import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { InstituicoesService } from '../instituicoes/instituicoes.service';
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
  let instituicoesService: {
    buscarPorId: jest.Mock;
    campusValido: jest.Mock;
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
    instituicoesService = {
      buscarPorId: jest.fn(),
      campusValido: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: repository,
        },
        {
          provide: InstituicoesService,
          useValue: instituicoesService,
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

  it('busca o perfil pelo identificador do Supabase', async () => {
    repository.findOne.mockResolvedValue({ idUsuario: 1 });

    await service.buscarPorAuthId('uuid-do-supabase');

    expect(repository.findOne).toHaveBeenCalledWith({
      where: { authId: 'uuid-do-supabase' },
    });
  });

  it('atualiza instituição e campus sem mudar o tipo do perfil', async () => {
    const usuario = {
      idUsuario: 1,
      idInstituicao: null,
      instituicao: null,
      campus: null,
      tipoPerfil: 'PASSAGEIRO',
    };
    repository.findOne.mockResolvedValue(usuario);
    instituicoesService.buscarPorId.mockResolvedValue({
      idInstituicao: 1,
      nome: 'Centro Universitário Salesiano',
    });
    repository.save.mockImplementation((dados: User) => Promise.resolve(dados));

    const resultado = await service.atualizarPerfil(1, 1, 'Araçatuba');

    expect(resultado?.idInstituicao).toBe(1);
    expect(resultado?.instituicao).toBe('Centro Universitário Salesiano');
    expect(resultado?.campus).toBe('Araçatuba');
    expect(resultado?.tipoPerfil).toBe('PASSAGEIRO');
    expect(repository.save).toHaveBeenCalledWith(usuario);
    expect(instituicoesService.campusValido).toHaveBeenCalledWith(
      1,
      'Araçatuba',
    );
  });

  it('salva a URL da foto no usuário', async () => {
    const usuario = { idUsuario: 1, fotoPerfil: null } as User;
    repository.save.mockImplementation((dados: User) => Promise.resolve(dados));

    const resultado = await service.atualizarFotoPerfil(
      usuario,
      'https://exemplo.com/foto',
    );

    expect(resultado.fotoPerfil).toBe('https://exemplo.com/foto');
    expect(repository.save).toHaveBeenCalledWith(usuario);
  });
});
