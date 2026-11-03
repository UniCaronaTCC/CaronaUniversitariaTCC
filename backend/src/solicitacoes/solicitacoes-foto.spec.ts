import { SolicitacoesController } from './solicitacoes.controller';
import { SolicitacoesService } from './solicitacoes.service';

describe('Fotos nas respostas de solicitacoes', () => {
  const req = { usuario: { sub: 7 } } as never;
  const prazo = new Date('2026-11-03T16:07:00.000Z');
  const servico = {
    listarRecebidas: jest.fn(),
    listarRecebidasDaCarona: jest.fn(),
    listarEnviadas: jest.fn(),
  };
  const controller = new SolicitacoesController(
    servico as unknown as SolicitacoesService,
  );
  beforeEach(() => jest.resetAllMocks());

  for (const foto of ['https://example.test/perfil-123?v=2', null, undefined]) {
    const pessoa = {
      idUsuario: 8,
      nome: 'Outra pessoa',
      fotoPerfil: foto,
      cpf: 'privado',
      email: 'privado@example.test',
    };
    const solicitacao = {
      idSolicitacao: 1,
      passageiro: pessoa,
      carona: {
        idCarona: 2,
        usuario: pessoa,
        dataInicio: '2026-11-05',
        horario: '14:00:00',
      },
      status: 'ACEITA',
      pagamentoLimiteEm: prazo,
      pagamentoConfirmado: false,
    };

    it(`envia somente foto e dados publicos do motorista: ${foto}`, async () => {
      servico.listarEnviadas.mockResolvedValue([solicitacao]);
      const resposta = await controller.listarEnviadas(req);
      expect(servico.listarEnviadas).toHaveBeenCalledWith(7);
      expect(resposta.dados[0].motorista).toEqual({
        id: 8,
        nome: pessoa.nome,
        fotoPerfil: foto ?? null,
      });
      expect(resposta.dados[0].pagamentoLimiteEm).toBe(prazo);
    });

    it(`envia foto do passageiro nas duas consultas de recebidas: ${foto}`, async () => {
      servico.listarRecebidas.mockResolvedValue([solicitacao]);
      servico.listarRecebidasDaCarona.mockResolvedValue([solicitacao]);
      for (const resposta of [
        await controller.listarRecebidas(req),
        await controller.listarRecebidasDaCarona('2', req),
      ]) {
        expect(resposta.dados[0].passageiro).toEqual({
          id: 8,
          nome: pessoa.nome,
          fotoPerfil: foto ?? null,
        });
        expect(resposta.dados[0].pagamentoLimiteEm).toBe(prazo);
      }
      expect(servico.listarRecebidas).toHaveBeenCalledWith(7);
      expect(servico.listarRecebidasDaCarona).toHaveBeenCalledWith(7, 2);
    });
  }
});
