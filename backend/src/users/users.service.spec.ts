import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { InstituicoesService } from '../instituicoes/instituicoes.service';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { Veiculo } from './veiculo.entity';
import { ForbiddenException } from '@nestjs/common';

describe('UsersService', () => {
  let service: UsersService;
  let repository: {
    findOne: jest.Mock;
    save: jest.Mock;
  };
  let instituicoesService: {
    buscarPorId: jest.Mock;
    campusValido: jest.Mock;
  };
  let veiculosRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };

  beforeEach(async () => {
    repository = {
      findOne: jest.fn(),
      save: jest.fn(),
    };
    instituicoesService = {
      buscarPorId: jest.fn(),
      campusValido: jest.fn().mockResolvedValue(true),
    };
    veiculosRepository = {
      findOne: jest.fn(),
      create: jest.fn().mockReturnValue({}),
      save: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: repository,
        },
        {
          provide: getRepositoryToken(Veiculo),
          useValue: veiculosRepository,
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

  it('libera ofertas com CNH aprovada, categoria adequada e validade vigente', async () => {
    repository.findOne.mockResolvedValue({
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'AB',
      cnhValidade: '2099-10-07',
    });
    await expect(
      service.exigirCnhParaOferecerCarona(1),
    ).resolves.toBeUndefined();
  });

  it.each([
    null,
    { statusVerificacaoCnh: 'NAO_ENVIADA' },
    { statusVerificacaoCnh: 'RECUSADA' },
    { statusVerificacaoCnh: 'EM_ANALISE' },
    {
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'A',
      cnhValidade: '2099-10-07',
    },
    {
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'B',
      cnhValidade: '2000-10-07',
    },
  ])('bloqueia oferta com habilitação insuficiente: %j', async (usuario) => {
    repository.findOne.mockResolvedValue(usuario);
    await expect(service.exigirCnhParaOferecerCarona(1)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(repository.save).not.toHaveBeenCalled();
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

  it('cadastra um veículo para o usuário', async () => {
    veiculosRepository.findOne.mockResolvedValue(null);
    veiculosRepository.save.mockImplementation((dados: Veiculo) =>
      Promise.resolve({ ...dados, idVeiculo: 1 }),
    );

    const resultado = await service.salvarVeiculo(
      7,
      'Honda Civic',
      'Prata',
      'ABC1D23',
    );

    expect(resultado).toMatchObject({
      idVeiculo: 1,
      modelo: 'Honda Civic',
      cor: 'Prata',
      placa: 'ABC1D23',
      usuario: { idUsuario: 7 },
    });
  });
});
