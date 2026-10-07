import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { Carona } from './carona.entity';
import { RecorrenciaCarona } from './recorrencia.entity';
import { PontoEmbarqueRecorrencia } from './ponto-embarque-recorrencia.entity';
import type { DadosCriacaoCarona } from './caronas.service';
import { datasRecorrencia } from './datas-recorrencia';
import { UsersService } from '../users/users.service';
import { User } from '../users/user.entity';
import {
  cnhPermiteOferecerCarona,
  hojeEmSaoPaulo,
} from '../users/verificacao-cnh';

@Injectable()
export class RecorrenciasService
  implements OnApplicationBootstrap, OnModuleDestroy
{
  private readonly logger = new Logger(RecorrenciasService.name);
  private temporizador?: ReturnType<typeof setInterval>;
  private gerando = false;

  constructor(
    private readonly dataSource: DataSource,
    private readonly usersService: UsersService,
  ) {}

  onApplicationBootstrap() {
    void this.completarProgramacoes();
    // Retoma ao iniciar o backend e completa a janela sem depender do aplicativo.
    this.temporizador = setInterval(
      () => void this.completarProgramacoes(),
      60 * 60 * 1000,
    );
    this.temporizador.unref();
  }

  onModuleDestroy() {
    clearInterval(this.temporizador);
  }

  async criar(dados: DadosCriacaoCarona): Promise<Carona> {
    await this.usersService.exigirCnhParaOferecerCarona(dados.idUsuario);
    return this.dataSource.transaction(async (manager) => {
      const { idUsuario, ...configuracao } = dados;
      const repository = manager.getRepository(RecorrenciaCarona);
      const modelo = repository.create({ idUsuario });
      modelo.definirDados(configuracao);
      await repository.save(modelo);
      const caronas = await this.gerar(manager, modelo);
      if (!caronas.length)
        throw new BadRequestException(
          'Selecione dias com partidas futuras dentro do período informado',
        );
      return manager.getRepository(Carona).findOneOrFail({
        where: { idCarona: caronas[0].idCarona },
        relations: { usuario: { veiculo: true }, pontosEmbarque: true },
      });
    });
  }

  listar(idUsuario: number) {
    return this.dataSource.getRepository(RecorrenciaCarona).find({
      where: { idUsuario },
      relations: { pontosEmbarque: true },
      order: { idRecorrencia: 'DESC' },
    });
  }

  async atualizar(
    id: number,
    idUsuario: number,
    dados?: DadosCriacaoCarona,
    ativa?: boolean,
  ) {
    return this.dataSource.transaction(async (manager) => {
      const repository = manager.getRepository(RecorrenciaCarona);
      const modelo = await repository.findOne({
        where: { idRecorrencia: id, idUsuario },
        lock: { mode: 'pessimistic_write' },
      });
      if (!modelo) throw new NotFoundException('Recorrência não encontrada');
      if (ativa ?? modelo.ativa) {
        await this.usersService.exigirCnhParaOferecerCarona(idUsuario);
      }
      const pontosRepository = manager.getRepository(PontoEmbarqueRecorrencia);
      if (dados) {
        const { idUsuario: motorista, ...configuracao } = dados;
        if (motorista !== modelo.idUsuario)
          throw new NotFoundException('Recorrência não encontrada');
        await pontosRepository.delete({ idRecorrencia: id });
        modelo.definirDados(configuracao);
      } else {
        modelo.pontosEmbarque = await pontosRepository.find({
          where: { idRecorrencia: id },
        });
      }
      if (ativa !== undefined) modelo.ativa = ativa;
      await repository.save(modelo);
      await this.gerar(manager, modelo);
      return modelo;
    });
  }

  async completarProgramacoes() {
    if (this.gerando) return;
    this.gerando = true;
    try {
      const modelos = await this.dataSource
        .getRepository(RecorrenciaCarona)
        .find({
          where: { ativa: true },
          select: { idRecorrencia: true },
        });
      for (const modelo of modelos) {
        try {
          await this.dataSource.transaction(async (manager) => {
            const atual = await manager
              .getRepository(RecorrenciaCarona)
              .findOne({
                where: { idRecorrencia: modelo.idRecorrencia },
                lock: { mode: 'pessimistic_write' },
              });
            if (atual) {
              atual.pontosEmbarque = await manager
                .getRepository(PontoEmbarqueRecorrencia)
                .find({
                  where: { idRecorrencia: atual.idRecorrencia },
                });
              await this.gerar(manager, atual);
            }
          });
        } catch {
          this.logger.error(
            `Não foi possível gerar as datas da recorrência ${modelo.idRecorrencia}. Nova tentativa em uma hora.`,
          );
        }
      }
    } catch {
      this.logger.error(
        'Não foi possível carregar as recorrências. Confira a migração do banco.',
      );
    } finally {
      this.gerando = false;
    }
  }

  private async gerar(
    manager: EntityManager,
    modelo: RecorrenciaCarona,
  ): Promise<Carona[]> {
    if (!modelo.ativa) return [];
    const usuario = await manager.getRepository(User).findOne({
      where: { idUsuario: modelo.idUsuario },
    });
    if (!usuario || !cnhPermiteOferecerCarona(usuario, hojeEmSaoPaulo()))
      return [];
    const repository = manager.getRepository(Carona);
    const criadas: Carona[] = [];
    for (const data of datasRecorrencia(modelo.dados)) {
      // Inclusive canceladas: cancelar somente um dia não deve recriá-lo.
      if (
        await repository.exists({
          where: { idRecorrencia: modelo.idRecorrencia, dataOcorrencia: data },
        })
      )
        continue;
      const { pontosEmbarque, ...dados } = modelo.dados;
      const carona = repository.create({
        ...dados,
        idRecorrencia: modelo.idRecorrencia,
        dataOcorrencia: data,
        dataInicio: data,
        dataFim: null,
        recorrente: false,
        diasSemana: null,
        status: 'ATIVA',
        usuario: { idUsuario: modelo.idUsuario },
        pontosEmbarque: pontosEmbarque.map((ponto) => ({
          nome: ponto.nome,
          endereco: ponto.endereco,
          latitude: ponto.latitude,
          longitude: ponto.longitude,
          ordem: ponto.ordem,
        })),
      });
      criadas.push(await repository.save(carona));
    }
    return criadas;
  }
}
