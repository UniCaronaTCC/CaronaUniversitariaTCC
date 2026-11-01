import { DataSource } from 'typeorm';
import { EncerramentoCorridasService } from './encerramento-corridas.service';

describe('Encerramento automatico de corridas', () => {
  let consulta: jest.Mock;
  let service: EncerramentoCorridasService;
  beforeEach(() => {
    jest.useFakeTimers();
    consulta = jest.fn().mockResolvedValue([]);
    service = new EncerramentoCorridasService({
      query: consulta,
    } as unknown as DataSource);
  });
  afterEach(() => {
    service.onModuleDestroy();
    jest.useRealTimers();
  });

  it('limpa ao iniciar o servidor, repete a cada minuto e para ao desligar', async () => {
    await service.onModuleInit();
    expect(consulta).toHaveBeenCalledWith(
      'SELECT unicarona.encerrar_corridas_por_tempo()',
    );
    await jest.advanceTimersByTimeAsync(60_000);
    expect(consulta).toHaveBeenCalledTimes(2);
    service.onModuleDestroy();
    await jest.advanceTimersByTimeAsync(120_000);
    expect(consulta).toHaveBeenCalledTimes(2);
  });

  it('compartilha a verificacao em andamento entre as consultas', async () => {
    let concluir!: (valor: unknown[]) => void;
    consulta.mockReturnValue(
      new Promise((resolve) => {
        concluir = resolve;
      }),
    );
    const primeira = service.encerrarVencidas();
    const segunda = service.encerrarVencidas();
    expect(consulta).toHaveBeenCalledTimes(1);
    concluir([]);
    await Promise.all([primeira, segunda]);
    consulta.mockResolvedValue([]);
    await service.encerrarVencidas();
    expect(consulta).toHaveBeenCalledTimes(2);
  });

  it('permite tentar novamente depois de uma falha do banco', async () => {
    consulta.mockRejectedValueOnce(new Error('indisponivel'));
    await expect(service.encerrarVencidas()).rejects.toThrow('indisponivel');
    await service.encerrarVencidas();
    expect(consulta).toHaveBeenCalledTimes(2);
  });
});
