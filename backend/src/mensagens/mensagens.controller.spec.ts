import type { RequisicaoComUsuario } from '../auth/requisicao-com-usuario';
import { Conversa } from './conversa.entity';
import { MensagensController } from './mensagens.controller';
import { MensagensService } from './mensagens.service';

describe('MensagensController', () => {
  it('retorna as fotos dos dois participantes da conversa', async () => {
    const conversa = {
      idConversa: 30,
      criadoEm: new Date('2026-09-01T12:00:00.000Z'),
      solicitacao: {
        idSolicitacao: 10,
        status: 'ACEITA',
        passageiro: {
          idUsuario: 1,
          nome: 'Passageiro',
          fotoPerfil: 'https://exemplo.com/passageiro.jpg',
        },
        carona: {
          idCarona: 20,
          status: 'ATIVA',
          destino: 'UniSalesiano',
          dataInicio: '2026-09-02',
          horario: '19:00:00',
          usuario: {
            idUsuario: 2,
            nome: 'Motorista',
            fotoPerfil: 'https://exemplo.com/motorista.jpg',
          },
        },
      },
    } as unknown as Conversa;
    const mensagensService = {
      listarConversas: jest.fn().mockResolvedValue([
        {
          conversa,
          ultimaMensagem: null,
          mensagensNaoLidas: 0,
        },
      ]),
    } as unknown as MensagensService;
    const controller = new MensagensController(mensagensService);
    const request = {
      usuario: { sub: 1 },
    } as unknown as RequisicaoComUsuario;

    const resposta = await controller.listarConversas(request);

    expect(resposta.dados[0].solicitacao.passageiro.fotoPerfil).toBe(
      'https://exemplo.com/passageiro.jpg',
    );
    expect(resposta.dados[0].solicitacao.motorista.fotoPerfil).toBe(
      'https://exemplo.com/motorista.jpg',
    );
    expect(resposta.dados[0].encerrada).toBe(false);
  });

  it('retorna estado de encerramento junto das mensagens antigas', async () => {
    const conversa = {
      idConversa: 30,
      criadoEm: new Date(),
      solicitacao: {
        idSolicitacao: 10,
        status: 'ACEITA',
        passageiro: { idUsuario: 1, nome: 'Passageiro' },
        carona: {
          idCarona: 20,
          status: 'FINALIZADA',
          destino: 'Faculdade',
          dataInicio: '2026-10-07',
          horario: '18:00:00',
          usuario: { idUsuario: 2, nome: 'Motorista' },
        },
      },
    } as unknown as Conversa;
    const service = {
      listarMensagens: jest.fn().mockResolvedValue({
        conversa,
        mensagens: [
          {
            idMensagem: 40,
            conteudo: 'Mensagem antiga',
            criadoEm: new Date(),
            remetente: { idUsuario: 1 },
          },
        ],
      }),
      listarConversas: jest
        .fn()
        .mockResolvedValue([
          { conversa, mensagensNaoLidas: 0, ultimaMensagem: null },
        ]),
    } as unknown as MensagensService;
    const controller = new MensagensController(service);
    const request = { usuario: { sub: 1 } } as RequisicaoComUsuario;
    const resposta = await controller.listarMensagens('30', undefined, request);
    expect(resposta.dados[0].conteudo).toBe('Mensagem antiga');
    expect(resposta.conversa.status).toBe('ACEITA');
    expect(resposta.conversa.encerrada).toBe(true);
    expect(resposta.conversa.solicitacao.carona.status).toBe('FINALIZADA');
    const lista = await controller.listarConversas(request);
    expect(lista.dados[0].encerrada).toBe(true);
  });
});
