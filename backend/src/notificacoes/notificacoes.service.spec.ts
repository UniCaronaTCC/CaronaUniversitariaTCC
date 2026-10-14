import { IsNull, LessThan, Repository } from 'typeorm';
import { Notificacao } from './notificacao.entity';
import { NotificacoesService } from './notificacoes.service';

describe('NotificacoesService', () => {
  const repository = { find: jest.fn(), count: jest.fn(), update: jest.fn() };
  const service = new NotificacoesService(
    repository as unknown as Repository<Notificacao>,
  );
  beforeEach(() => {
    jest.resetAllMocks();
    repository.find.mockResolvedValue([]);
    repository.count.mockResolvedValue(0);
    repository.update.mockResolvedValue({ affected: 2 });
  });

  it('conta apenas avisos nao lidos do usuario autenticado', async () => {
    repository.count.mockResolvedValue(3);
    expect(await service.contar(7)).toBe(3);
    expect(repository.count).toHaveBeenCalledWith({
      where: { idUsuario: 7, lidaEm: IsNull() },
    });
  });

  it('consultar nao marca como lida e nao expoe campos internos', async () => {
    repository.find.mockResolvedValue([
      {
        id: 50,
        idUsuario: 7,
        tipo: 'CNH',
        titulo: 'CNH conferida',
        descricao: 'Resultado disponivel',
        chaveEvento: 'interno',
        referencias: { tela: 'CNH' },
        criadoEm: new Date(),
        lidaEm: null,
      },
    ]);
    const pagina = await service.listar(7);
    expect(pagina.itens[0]).not.toHaveProperty('idUsuario');
    expect(pagina.itens[0]).not.toHaveProperty('chaveEvento');
    expect(repository.update).not.toHaveBeenCalled();
    expect(repository.find).toHaveBeenCalledWith({
      where: { idUsuario: 7 },
      order: { id: 'DESC' },
      take: 51,
    });
  });

  it('abrir marca apenas nao lidas da propria conta e depois consulta', async () => {
    await service.abrir(7);
    const chamada = repository.update.mock.calls[0] as [
      unknown,
      { lidaEm: Date },
    ];
    expect(chamada[0]).toEqual({ idUsuario: 7, lidaEm: IsNull() });
    expect(chamada[1].lidaEm).toBeInstanceOf(Date);
    expect(repository.update.mock.invocationCallOrder[0]).toBeLessThan(
      repository.find.mock.invocationCallOrder[0],
    );
  });

  it('erro de atualizacao nao finge abertura bem sucedida', async () => {
    repository.update.mockRejectedValue(new Error('Falha sintetica'));
    await expect(service.abrir(7)).rejects.toThrow('Falha sintetica');
    expect(repository.find).not.toHaveBeenCalled();
  });

  it('pagina tem 50 avisos, cursor estavel e consulta limitada', async () => {
    repository.find.mockResolvedValue(
      Array.from({ length: 51 }, (_, i) => ({ id: 100 - i, titulo: 'Aviso' })),
    );
    const pagina = await service.listar(7, 101);
    expect(pagina.itens).toHaveLength(50);
    expect(pagina.temMais).toBe(true);
    expect(pagina.proximoAntesDe).toBe(51);
    expect(repository.find).toHaveBeenCalledWith({
      where: { idUsuario: 7, id: LessThan(101) },
      order: { id: 'DESC' },
      take: 51,
    });
  });

  it('lista vazia nao cria cursor nem altera contador', async () => {
    expect(await service.listar(8)).toEqual({
      itens: [],
      totalNaoLidas: 0,
      temMais: false,
      proximoAntesDe: null,
    });
  });
});
