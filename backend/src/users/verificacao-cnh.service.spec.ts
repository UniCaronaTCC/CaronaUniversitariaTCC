import {
  ConflictException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { DataSource, QueryFailedError, Repository } from 'typeorm';
import { Carona } from '../caronas/carona.entity';
import { RecorrenciaCarona } from '../caronas/recorrencia.entity';

import { LeituraCnhService } from './leitura-cnh.service';
import { User } from './user.entity';
import { VerificacaoCnhService } from './verificacao-cnh.service';
import { hojeEmSaoPaulo } from './verificacao-cnh';

describe('VerificacaoCnhService', () => {
  const texto = {
    texto: '',
    nome: 'JOAO PEDRO DA SILVA',
    registro: '12345678901',
    campos: { cpf: '529.982.247-25', categoria: 'B', validade: '06/10/2099' },
  };
  const frente = { largura: 1000, altura: 800, linhas: [] };
  let usuarios: { findOne: jest.Mock; update: jest.Mock };
  let leitura: { ler: jest.Mock };
  let service: VerificacaoCnhService;
  let ofertas: { exists: jest.Mock };
  let recorrencias: { exists: jest.Mock };
  let dataSource: { transaction: jest.Mock };

  beforeEach(() => {
    usuarios = {
      findOne: jest.fn().mockResolvedValue({
        idUsuario: 1,
        nome: 'João Pedro da Silva',
        statusVerificacaoCnh: 'NAO_ENVIADA',
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    leitura = {
      ler: jest.fn().mockReturnValue(texto),
    };
    ofertas = { exists: jest.fn().mockResolvedValue(false) };
    recorrencias = { exists: jest.fn().mockResolvedValue(false) };
    dataSource = {
      transaction: jest.fn(
        (
          executar: (manager: {
            getRepository: (entity: unknown) => unknown;
          }) => Promise<unknown>,
        ) =>
          executar({
            getRepository: (entity: unknown) =>
              entity === User
                ? usuarios
                : entity === Carona
                  ? ofertas
                  : entity === RecorrenciaCarona
                    ? recorrencias
                    : null,
          }),
      ),
    };
    service = new VerificacaoCnhService(
      usuarios as unknown as Repository<User>,
      leitura as unknown as LeituraCnhService,
      dataSource as unknown as DataSource,
    );
  });
  it('salva nome e registro lidos sem alterar nome do perfil', async () => {
    leitura.ler.mockReturnValue({ ...texto, registro: '12345678901' });
    await expect(service.verificar(1, frente)).resolves.toEqual({
      status: 'APROVADA',
    });
    const [, alteracoes] = usuarios.update.mock.calls[0] as [
      number,
      Partial<User>,
    ];
    expect(alteracoes).toMatchObject({
      cnhNome: texto.nome,
      cnhRegistro: '12345678901',
      cnhRegistroFinal: '8901',
    });
    expect(alteracoes).not.toHaveProperty('nome');
  });

  it('consulta os dados privados somente da conta solicitada', async () => {
    usuarios.findOne.mockResolvedValue({
      idUsuario: 7,
      cnhNome: 'MARIA SILVA',
      cnhRegistro: '12345678901',
    });
    expect(await service.buscarDados(7)).toEqual({
      nome: 'MARIA SILVA',
      registro: '12345678901',
    });
    expect(usuarios.findOne).toHaveBeenCalledWith({
      where: { idUsuario: 7 },
      select: { idUsuario: true, cnhNome: true, cnhRegistro: true },
    });
  });

  it('reinicia somente os campos da CNH e permite uma nova leitura', async () => {
    await expect(service.reiniciarParaTeste(1)).resolves.toEqual({
      status: 'NAO_ENVIADA',
    });
    expect(usuarios.update).toHaveBeenCalledWith(1, {
      statusVerificacaoCnh: 'NAO_ENVIADA',
      cpf: null,
      cnhNome: null,
      cnhRegistro: null,
      cnhCategoria: null,
      cnhValidade: null,
      cnhRegistroFinal: null,
      cnhVerificadaEm: null,
      privacidadeAceitaEm: null,
    });
    expect(usuarios.findOne).toHaveBeenCalledWith({
      where: { idUsuario: 1 },
      lock: { mode: 'pessimistic_write' },
    });
    await service.verificar(1, frente);
    expect(leitura.ler).toHaveBeenCalledTimes(1);
  });

  it('executa aprovar, reiniciar e aprovar novamente sem reutilizar o OCR antigo', async () => {
    const usuario = {
      idUsuario: 1,
      nome: 'Teste',
      statusVerificacaoCnh: 'NAO_ENVIADA',
    };
    usuarios.findOne.mockImplementation(() => Promise.resolve({ ...usuario }));
    usuarios.update.mockImplementation((_id: number, campos: object) => {
      Object.assign(usuario, campos);
      return Promise.resolve({ affected: 1 });
    });
    await service.verificar(1, frente);
    expect(usuario.statusVerificacaoCnh).toBe('APROVADA');
    await service.reiniciarParaTeste(1);
    expect(usuario.statusVerificacaoCnh).toBe('NAO_ENVIADA');
    expect(usuario.nome).toBe('Teste');
    await service.verificar(1, frente);
    expect(usuario.statusVerificacaoCnh).toBe('APROVADA');
    expect(leitura.ler).toHaveBeenCalledTimes(2);
  });

  it('bloqueia clique duplicado e novo envio enquanto o reset esta pendente', async () => {
    let concluir!: () => void;
    const aguardando = new Promise<void>((resolve) => (concluir = resolve));
    dataSource.transaction.mockImplementationOnce(() => aguardando);
    const primeiro = service.reiniciarParaTeste(1);
    await expect(service.reiniciarParaTeste(1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    await expect(service.verificar(1, frente)).rejects.toBeInstanceOf(
      ConflictException,
    );
    concluir();
    await primeiro;
    await expect(service.reiniciarParaTeste(1)).resolves.toEqual({
      status: 'NAO_ENVIADA',
    });
  });

  it.each([1, 2, 7, 42])(
    'reinicia a propria conta %s sem configuracao adicional',
    async (idUsuario) => {
      usuarios.findOne.mockResolvedValue({ idUsuario });
      await expect(service.reiniciarParaTeste(idUsuario)).resolves.toEqual({
        status: 'NAO_ENVIADA',
      });
      expect(usuarios.update).toHaveBeenCalledWith(
        idUsuario,
        expect.objectContaining({ statusVerificacaoCnh: 'NAO_ENVIADA' }),
      );
    },
  );

  it('nao altera dados de usuario inexistente', async () => {
    usuarios.findOne.mockResolvedValue(null);
    await expect(service.reiniciarParaTeste(42)).rejects.toThrow(
      'Usuário não encontrado',
    );
    expect(usuarios.update).not.toHaveBeenCalled();
  });

  it.each(['carona', 'recorrencia'])(
    'bloqueia reset com %s ativa',
    async (tipo) => {
      (tipo === 'carona' ? ofertas : recorrencias).exists.mockResolvedValue(
        true,
      );
      await expect(service.reiniciarParaTeste(1)).rejects.toThrow(
        'ofertas ativas',
      );
      expect(usuarios.update).not.toHaveBeenCalled();
    },
  );

  it('nao anuncia reset se nenhuma linha foi atualizada', async () => {
    usuarios.update.mockResolvedValue({ affected: 0 });
    await expect(service.reiniciarParaTeste(1)).rejects.toThrow(
      'Usuário não encontrado',
    );
  });

  it('libera o bloqueio depois de falha no banco', async () => {
    usuarios.update.mockRejectedValueOnce(new Error('falha'));
    await expect(service.reiniciarParaTeste(1)).rejects.toThrow('falha');
    await expect(service.reiniciarParaTeste(1)).resolves.toEqual({
      status: 'NAO_ENVIADA',
    });
  });

  it('impede reset enquanto a verificacao esta em andamento', async () => {
    let concluir!: (valor: object) => void;
    usuarios.findOne.mockReturnValueOnce(
      new Promise<object>((resolve) => (concluir = resolve)),
    );
    const envio = service.verificar(1, frente);
    await Promise.resolve();
    await expect(service.reiniciarParaTeste(1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    concluir({ idUsuario: 1, statusVerificacaoCnh: 'NAO_ENVIADA' });
    await envio;
  });

  it('usa o dia local de São Paulo', () => {
    expect(hojeEmSaoPaulo(new Date('2026-10-07T02:30:00Z'))).toBe('2026-10-06');
  });

  it('registra diagnóstico sem nome, CPF, OCR ou buffers e sem mudar a resposta', async () => {
    const logs: unknown[] = [];
    const log = jest
      .spyOn(Logger.prototype, 'log')
      .mockImplementation((mensagem: unknown) => {
        logs.push(mensagem);
      });
    const warn = jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation((mensagem: unknown) => {
        logs.push(mensagem);
      });
    try {
      leitura.ler.mockReturnValue({ ...texto, nome: null });
      const resposta = await service.verificar(1, frente);
      expect(resposta).toEqual({ status: 'RECUSADA', motivo: 'NOME_NAO_LIDO' });

      const serializado = JSON.stringify(logs);
      for (const dado of [
        'JOAO PEDRO',
        'João Pedro',
        '529.982',
        '12345678901',
        'frente',
        'verso',
      ]) {
        expect(serializado).not.toContain(dado);
      }
    } finally {
      log.mockRestore();
      warn.mockRestore();
    }
  });

  it('aprova e persiste apenas os campos definidos', async () => {
    usuarios.findOne.mockResolvedValue({
      idUsuario: 1,
      nome: 'João',
      statusVerificacaoCnh: 'NAO_ENVIADA',
    });
    await expect(service.verificar(1, frente)).resolves.toEqual({
      status: 'APROVADA',
    });
    expect(leitura.ler).toHaveBeenCalledWith(frente);
    const [idUsuario, alteracoes] = usuarios.update.mock.calls[0] as [
      number,
      Partial<User>,
    ];
    expect(idUsuario).toBe(1);
    expect(alteracoes).toMatchObject({
      statusVerificacaoCnh: 'APROVADA',
      cpf: '52998224725',
      cnhCategoria: 'B',
      cnhValidade: '2099-10-06',
      cnhNome: texto.nome,
      cnhRegistro: texto.registro,
      cnhRegistroFinal: '8901',
    });
    expect(alteracoes.cnhVerificadaEm).toBeInstanceOf(Date);
    expect(alteracoes.privacidadeAceitaEm).toBeInstanceOf(Date);
    expect(alteracoes).not.toHaveProperty('nome');
    expect(alteracoes).not.toHaveProperty('nomeCompleto');
  });

  it('envia sem solicitar nome digitado', async () => {
    await expect(service.verificar(1, frente)).resolves.toEqual({
      status: 'APROVADA',
    });
    expect(leitura.ler).toHaveBeenCalledWith(frente);
  });

  it('recusa leitura inconclusiva e não guarda dados parciais', async () => {
    leitura.ler.mockReturnValue({
      ...texto,
      campos: { ...texto.campos, cpf: null },
    });
    await expect(service.verificar(1, frente)).resolves.toEqual({
      status: 'RECUSADA',
      motivo: 'CPF_NAO_LIDO',
    });
    expect(usuarios.update).toHaveBeenCalledWith(
      1,
      expect.objectContaining({
        statusVerificacaoCnh: 'RECUSADA',
        cpf: null,
        cnhCategoria: null,
        cnhValidade: null,
        cnhRegistroFinal: null,
      }),
    );
  });

  it('não muda o banco quando o OCR falha', async () => {
    leitura.ler.mockImplementation(() => {
      throw new ServiceUnavailableException();
    });
    await expect(service.verificar(1, frente)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(usuarios.update).not.toHaveBeenCalled();
  });

  it('não refaz uma aprovação ainda válida', async () => {
    usuarios.findOne.mockResolvedValue({
      idUsuario: 1,
      nome: 'João Pedro da Silva',
      statusVerificacaoCnh: 'APROVADA',
      cnhCategoria: 'B',
      cnhValidade: '2099-10-06',
    });
    await expect(service.verificar(1, frente)).resolves.toEqual({
      status: 'APROVADA',
    });
    expect(leitura.ler).not.toHaveBeenCalled();
    expect(usuarios.update).not.toHaveBeenCalled();
  });

  it('trata CPF já associado sem expor o número', async () => {
    usuarios.update.mockRejectedValue(
      new QueryFailedError('UPDATE', [], {
        code: '23505',
        constraint: 'uq_usuarios_cpf',
      }),
    );
    await expect(service.verificar(1, frente)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
