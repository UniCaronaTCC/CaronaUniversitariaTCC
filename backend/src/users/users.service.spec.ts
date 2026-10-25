import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { InstituicoesService } from '../instituicoes/instituicoes.service';
import { User } from './user.entity';
import { UsersService } from './users.service';
import { Veiculo } from './veiculo.entity';
import { ForbiddenException } from '@nestjs/common';
import { EntityManager, In, QueryFailedError } from 'typeorm';
import { Carona } from '../caronas/carona.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';

describe('UsersService', () => {
  let service: UsersService;
  let repository: {
    findOne: jest.Mock;
    save: jest.Mock;
    update: jest.Mock;
    manager: { transaction: jest.Mock };
  };
  let instituicoesService: {
    buscarPorId: jest.Mock;
    campusValido: jest.Mock;
  };
  let veiculosRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let usuarioBloqueado: jest.Mock;
  let caronasQuery: Record<string, jest.Mock>;
  let temAceites: jest.Mock;

  beforeEach(async () => {
    repository = {
      findOne: jest.fn(),
      save: jest.fn(),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      manager: { transaction: jest.fn() },
    };
    instituicoesService = {
      buscarPorId: jest.fn(),
      campusValido: jest.fn().mockResolvedValue(true),
    };
    veiculosRepository = {
      findOne: jest.fn(),
      create: jest
        .fn()
        .mockImplementation((dados: Partial<Veiculo>) => ({ ...dados })),
      save: jest.fn(),
      createQueryBuilder: jest.fn(),
    };
    usuarioBloqueado = jest.fn().mockResolvedValue({ idUsuario: 1 });
    temAceites = jest.fn().mockResolvedValue(false);
    caronasQuery = Object.fromEntries(
      ['select', 'where', 'andWhere', 'orderBy', 'setLock'].map((nome) => [
        nome,
        jest.fn().mockReturnThis(),
      ]),
    );
    caronasQuery.getMany = jest.fn().mockResolvedValue([]);
    veiculosRepository.createQueryBuilder.mockReturnValue({
      where: jest.fn().mockReturnThis(),
      setLock: jest.fn().mockReturnThis(),
      getOne: veiculosRepository.findOne,
    });
    const manager = {
      getRepository: jest.fn().mockImplementation((entidade: unknown) => {
        if (entidade === User) return { findOne: usuarioBloqueado };
        if (entidade === Veiculo) return veiculosRepository;
        if (entidade === Carona)
          return { createQueryBuilder: () => caronasQuery };
        if (entidade === Solicitacao) return { exists: temAceites };
        throw new Error('Repositorio inesperado');
      }),
    };
    repository.manager.transaction.mockImplementation(
      (trabalho: (manager: EntityManager) => Promise<unknown>) =>
        trabalho(manager as unknown as EntityManager),
    );

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

    const resultado = await service.atualizarPerfil(1, 1, 'Araçatuba');

    expect(resultado?.idInstituicao).toBe(1);
    expect(resultado?.instituicao).toBe('Centro Universitário Salesiano');
    expect(resultado?.campus).toBe('Araçatuba');
    expect(resultado?.tipoPerfil).toBe('PASSAGEIRO');
    expect(repository.update).toHaveBeenCalledWith(1, {
      idInstituicao: 1,
      instituicao: 'Centro Universitário Salesiano',
      campus: 'Araçatuba',
    });
    expect(repository.save).not.toHaveBeenCalled();
    expect(instituicoesService.campusValido).toHaveBeenCalledWith(
      1,
      'Araçatuba',
    );
  });

  it('salva a URL da foto no usuário', async () => {
    const usuario = { idUsuario: 1, fotoPerfil: null } as User;

    const resultado = await service.atualizarFotoPerfil(
      usuario,
      'https://exemplo.com/foto',
    );

    expect(resultado.fotoPerfil).toBe('https://exemplo.com/foto');
    expect(repository.update).toHaveBeenCalledWith(1, {
      fotoPerfil: 'https://exemplo.com/foto',
    });
    expect(repository.save).not.toHaveBeenCalled();
  });

  it.each([null, { idVeiculo: 7 }])(
    'atualiza somente a foto sem persistir veiculo ou CNH: %j',
    async (veiculo) => {
      const usuario = Object.assign(new User(), {
        idUsuario: 1,
        fotoPerfil: 'https://exemplo.com/antiga',
        veiculo,
        statusVerificacaoCnh: 'APROVADA',
        cnhCategoria: 'AB',
        cnhValidade: '2099-05-01',
      });
      const antes = { ...usuario };

      const resultado = await service.atualizarFotoPerfil(
        usuario,
        'https://exemplo.com/nova',
      );

      expect(repository.update).toHaveBeenCalledWith(1, {
        fotoPerfil: 'https://exemplo.com/nova',
      });
      expect(resultado).toEqual({
        ...antes,
        fotoPerfil: 'https://exemplo.com/nova',
      });
      expect(repository.save).not.toHaveBeenCalled();
      expect(veiculosRepository.save).not.toHaveBeenCalled();
    },
  );

  it('nao altera a foto em memoria quando o banco recusa a atualizacao', async () => {
    const usuario = Object.assign(new User(), {
      idUsuario: 1,
      fotoPerfil: 'https://exemplo.com/antiga',
    });
    repository.update.mockRejectedValue(new Error('falha no banco'));

    await expect(
      service.atualizarFotoPerfil(usuario, 'https://exemplo.com/nova'),
    ).rejects.toThrow('falha no banco');
    expect(usuario.fotoPerfil).toBe('https://exemplo.com/antiga');
    expect(repository.save).not.toHaveBeenCalled();
  });

  it('informa se o usuario foi removido antes de salvar a foto', async () => {
    const usuario = Object.assign(new User(), {
      idUsuario: 1,
      fotoPerfil: null,
    });
    repository.update.mockResolvedValue({ affected: 0 });

    await expect(
      service.atualizarFotoPerfil(usuario, 'https://exemplo.com/nova'),
    ).rejects.toThrow('Usuário não encontrado');
    expect(usuario.fotoPerfil).toBeNull();
  });

  it('preserva veiculo, foto e CNH ao editar instituicao e campus', async () => {
    const usuario = Object.assign(new User(), {
      idUsuario: 1,
      fotoPerfil: 'https://exemplo.com/foto',
      veiculo: null,
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'AB',
      cnhValidade: '2099-05-01',
    });
    const antes = { ...usuario };
    repository.findOne.mockResolvedValue(usuario);
    instituicoesService.buscarPorId.mockResolvedValue({
      idInstituicao: 2,
      nome: 'Universidade',
    });

    const resultado = await service.atualizarPerfil(1, 2, 'Campus');

    const alteracoes = {
      idInstituicao: 2,
      instituicao: 'Universidade',
      campus: 'Campus',
    };
    expect(repository.update).toHaveBeenCalledWith(1, alteracoes);
    expect(resultado).toEqual({ ...antes, ...alteracoes });
    expect(repository.save).not.toHaveBeenCalled();
    expect(veiculosRepository.save).not.toHaveBeenCalled();
  });

  it('nao atualiza o perfil para um campus invalido', async () => {
    repository.findOne.mockResolvedValue({ idUsuario: 1 });
    instituicoesService.buscarPorId.mockResolvedValue({
      idInstituicao: 2,
      nome: 'Universidade',
    });
    instituicoesService.campusValido.mockResolvedValue(false);

    await expect(service.atualizarPerfil(1, 2, 'Invalido')).rejects.toThrow(
      'Campus inválido',
    );
    expect(repository.update).not.toHaveBeenCalled();
  });

  it('retorna null se o usuario foi removido durante a edicao do perfil', async () => {
    repository.findOne.mockResolvedValue({ idUsuario: 1 });
    instituicoesService.buscarPorId.mockResolvedValue({
      idInstituicao: 2,
      nome: 'Universidade',
    });
    repository.update.mockResolvedValue({ affected: 0 });

    await expect(service.atualizarPerfil(1, 2, 'Campus')).resolves.toBeNull();
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

  it('edita o mesmo veiculo sem alterar seu proprietario ou o perfil', async () => {
    const existente = {
      idVeiculo: 7,
      usuario: { idUsuario: 1 },
      modelo: 'Onix',
      cor: 'Prata',
      placa: 'ABC1234',
    };
    veiculosRepository.findOne.mockResolvedValue(existente);
    veiculosRepository.save.mockImplementation((veiculo: Veiculo) =>
      Promise.resolve(veiculo),
    );
    await expect(
      service.salvarVeiculo(1, 'Honda Civic', 'Azul escuro', 'XYZ9Z99'),
    ).resolves.toMatchObject({
      idVeiculo: 7,
      usuario: { idUsuario: 1 },
      modelo: 'Honda Civic',
      cor: 'Azul escuro',
      placa: 'XYZ9Z99',
    });
    expect(repository.save).not.toHaveBeenCalled();
    expect(repository.update).not.toHaveBeenCalled();
    expect(veiculosRepository.create).not.toHaveBeenCalled();
  });

  it('traduz placa duplicada em conflito com erro no campo', async () => {
    veiculosRepository.findOne.mockResolvedValue(null);
    veiculosRepository.save.mockRejectedValue(
      new QueryFailedError(
        'INSERT',
        [],
        Object.assign(new Error('unique'), { code: '23505' }),
      ),
    );
    await expect(
      service.salvarVeiculo(1, 'Honda Civic', 'Prata', 'ABC1D23'),
    ).rejects.toMatchObject({
      response: {
        message: 'Esta placa j\u00e1 est\u00e1 cadastrada',
        campos: { placa: 'Esta placa j\u00e1 est\u00e1 cadastrada' },
      },
    });
  });

  it('nao classifica indisponibilidade do banco como placa duplicada', async () => {
    veiculosRepository.findOne.mockResolvedValue(null);
    const erro = new Error('database unavailable');
    veiculosRepository.save.mockRejectedValue(erro);
    await expect(
      service.salvarVeiculo(1, 'Honda Civic', 'Prata', 'ABC1D23'),
    ).rejects.toBe(erro);
  });

  it('bloqueia alteracoes durante uma viagem mesmo sem passageiros aceitos', async () => {
    caronasQuery.getMany.mockResolvedValue([
      { idCarona: 10, status: 'EM_ANDAMENTO' },
    ]);
    await expect(
      service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234'),
    ).rejects.toMatchObject({ status: 409 });
    expect(veiculosRepository.save).not.toHaveBeenCalled();
    expect(temAceites).not.toHaveBeenCalled();
  });

  it.each(['ATIVA', 'LOTADA'])(
    'bloqueia troca com passageiros aceitos em carona %s',
    async (status) => {
      caronasQuery.getMany.mockResolvedValue([{ idCarona: 10, status }]);
      temAceites.mockResolvedValue(true);
      await expect(
        service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234'),
      ).rejects.toMatchObject({ status: 409 });
      expect(veiculosRepository.save).not.toHaveBeenCalled();
      expect(temAceites).toHaveBeenCalledWith({
        where: {
          carona: { idCarona: In([10]) },
          status: 'ACEITA',
        },
      });
      expect(caronasQuery.getMany.mock.invocationCallOrder[0]).toBeLessThan(
        temAceites.mock.invocationCallOrder[0],
      );
    },
  );

  it('permite trocar quando nao ha aceites nas caronas validas', async () => {
    caronasQuery.getMany.mockResolvedValue([{ idCarona: 10, status: 'ATIVA' }]);
    await service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234');
    expect(veiculosRepository.save).toHaveBeenCalledTimes(1);
    expect(caronasQuery.setLock).toHaveBeenCalledWith('pessimistic_write');
    expect(caronasQuery.where).toHaveBeenCalledWith('id_usuario = :idUsuario', {
      idUsuario: 1,
    });
    expect(caronasQuery.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('OR NOT'),
    );
    expect(usuarioBloqueado).toHaveBeenCalledWith({
      where: { idUsuario: 1 },
      lock: { mode: 'for_no_key_update' },
    });
  });

  it('salvar os mesmos dados e idempotente mesmo com viagens em andamento', async () => {
    const existente = { modelo: 'Onix', cor: 'Branco', placa: 'ABC1234' };
    veiculosRepository.findOne.mockResolvedValue(existente);
    await expect(
      service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234'),
    ).resolves.toBe(existente);
    expect(caronasQuery.getMany).not.toHaveBeenCalled();
    expect(veiculosRepository.save).not.toHaveBeenCalled();
  });

  it('nao salva veiculo se o usuario deixou de existir', async () => {
    usuarioBloqueado.mockResolvedValue(null);
    await expect(
      service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234'),
    ).rejects.toMatchObject({ status: 404 });
    expect(veiculosRepository.save).not.toHaveBeenCalled();
  });

  it('nao atribui conflito do usuario ao campo placa', async () => {
    veiculosRepository.save.mockRejectedValue(
      new QueryFailedError(
        'INSERT',
        [],
        Object.assign(new Error('unique'), {
          code: '23505',
          constraint: 'uq_veiculos_usuario',
        }),
      ),
    );
    await expect(
      service.salvarVeiculo(1, 'Onix', 'Branco', 'ABC1234'),
    ).rejects.toMatchObject({
      response: {
        statusCode: 409,
        message:
          'O cadastro do ve\u00edculo foi atualizado. Atualize o perfil antes de tentar novamente',
      },
    });
  });
});
