import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { DataSource } from 'typeorm';

export const STATUS_ENCERRADA_POR_TEMPO = 'ENCERRADA_POR_TEMPO';
export const MENSAGEM_ENCERRADA_POR_TEMPO =
  'Corrida encerrada automaticamente por tempo';

@Injectable()
export class EncerramentoCorridasService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(EncerramentoCorridasService.name);
  private timer: NodeJS.Timeout | null = null;
  private execucao: Promise<void> | null = null;

  constructor(private readonly dataSource: DataSource) {}

  async onModuleInit(): Promise<void> {
    await this.verificarAutomaticamente();
    this.timer = setInterval(
      () => void this.verificarAutomaticamente(),
      60_000,
    );
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  encerrarVencidas(): Promise<void> {
    // As listagens e o timer compartilham a mesma verificacao em andamento.
    this.execucao ??= this.dataSource
      .query('SELECT unicarona.encerrar_corridas_por_tempo()')
      .then(() => undefined)
      .finally(() => {
        this.execucao = null;
      });
    return this.execucao;
  }

  private async verificarAutomaticamente(): Promise<void> {
    try {
      await this.encerrarVencidas();
    } catch {
      this.logger.error(
        'Nao foi possivel encerrar corridas vencidas. Confira a migracao do banco e a conexao.',
      );
    }
  }
}
