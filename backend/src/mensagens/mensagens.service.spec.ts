import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Repository } from 'typeorm';

import { Solicitacao } from '../solicitacoes/solicitacao.entity';
import { Conversa } from './conversa.entity';
import { Mensagem } from './mensagem.entity';
import { MensagensService } from './mensagens.service';

describe('MensagensService', () => {
  let service: MensagensService;
  let conversasRepository: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let mensagensRepository: {
    findOne: jest.Mock;
    find: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let solicitacoesRepository: { findOne: jest.Mock };

  const solicitacaoAceita = {
    idSolicitacao: 10,
    status: 'ACEITA',
    passageiro: { idUsuario: 1, nome: 'Passageiro' },
    carona: {
      idCarona: 20,
      usuario: { idUsuario: 2, nome: 'Motorista' },
    },
  } as Solicitacao;

  beforeEach(() => {
    conversasRepository = {
      findOne: jest.fn(),
      create: jest.fn((dados: Partial<Conversa>) => dados as Conversa),
      save: jest.fn((dados: Conversa) =>
        Promise.resolve({ ...dados, idConversa: 30 }),
      ),
      createQueryBuilder: jest.fn(),
    };

    mensagensRepository = {
      findOne: jest.fn(),
      find: jest.fn(),
      create: jest.fn((dados: Partial<Mensagem>) => dados as Mensagem),
      save: jest.fn((dados: Mensagem) =>
        Promise.resolve({ ...dados, idMensagem: 40 }),
      ),
    };

    solicitacoesRepository = { findOne: jest.fn() };

    service = new MensagensService(
      conversasRepository as unknown as Repository<Conversa>,
      mensagensRepository as unknown as Repository<Mensagem>,
      solicitacoesRepository as unknown as Repository<Solicitacao>,
    );
  });

  it('cria conversa para uma solicitação aceita', async () => {
    conversasRepository.findOne.mockResolvedValue(null);
    solicitacoesRepository.findOne.mockResolvedValue(solicitacaoAceita);

    const conversa = await service.obterOuCriarConversa(10, 1);

    expect(conversa.idConversa).toBe(30);
    expect(conversasRepository.create).toHaveBeenCalledWith({
      solicitacao: solicitacaoAceita,
    });
  });

  it('não libera chat antes da solicitação ser aceita', async () => {
    conversasRepository.findOne.mockResolvedValue(null);
    solicitacoesRepository.findOne.mockResolvedValue({
      ...solicitacaoAceita,
      status: 'PENDENTE',
    });

    await expect(service.obterOuCriarConversa(10, 1)).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(conversasRepository.save).not.toHaveBeenCalled();
  });

  it('não revela a conversa para quem não participa da carona', async () => {
    conversasRepository.findOne.mockResolvedValue({
      idConversa: 30,
      solicitacao: solicitacaoAceita,
    });

    await expect(service.obterOuCriarConversa(10, 99)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('ordena conversas pela mensagem mais recente', async () => {
    const conversaSemMensagem = {
      idConversa: 1,
      criadoEm: new Date('2026-09-01T10:00:00.000Z'),
    } as Conversa;
    const conversaComMensagemNova = {
      idConversa: 2,
      criadoEm: new Date('2026-08-20T10:00:00.000Z'),
    } as Conversa;
    const queryBuilder = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      getMany: jest
        .fn()
        .mockResolvedValue([conversaSemMensagem, conversaComMensagemNova]),
    };

    conversasRepository.createQueryBuilder.mockReturnValue(queryBuilder);
    mensagensRepository.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        idMensagem: 5,
        criadoEm: new Date('2026-09-02T10:00:00.000Z'),
      });

    const resultado = await service.listarConversas(1);

    expect(resultado.map((item) => item.conversa.idConversa)).toEqual([2, 1]);
  });

  it('salva mensagem sem espaços extras', async () => {
    conversasRepository.findOne.mockResolvedValue({
      idConversa: 30,
      solicitacao: solicitacaoAceita,
    });

    const mensagem = await service.enviarMensagem(30, 2, '  Olá!  ');

    expect(mensagem.idMensagem).toBe(40);
    expect(mensagensRepository.create).toHaveBeenCalledWith({
      conversa: { idConversa: 30 },
      remetente: { idUsuario: 2 },
      conteudo: 'Olá!',
    });
  });

  it('recusa mensagem vazia', async () => {
    conversasRepository.findOne.mockResolvedValue({
      idConversa: 30,
      solicitacao: solicitacaoAceita,
    });

    await expect(service.enviarMensagem(30, 1, '   ')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(mensagensRepository.save).not.toHaveBeenCalled();
  });

  it('mantém conversa cancelada somente para leitura', async () => {
    conversasRepository.findOne.mockResolvedValue({
      idConversa: 30,
      solicitacao: {
        ...solicitacaoAceita,
        status: 'CANCELADA_PASSAGEIRO',
      },
    });

    await expect(
      service.enviarMensagem(30, 1, 'Ainda está aí?'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(mensagensRepository.save).not.toHaveBeenCalled();
  });
});
