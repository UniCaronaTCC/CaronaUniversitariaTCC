import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { Carona } from './carona.entity';
import { PontoEmbarque } from './ponto-embarque.entity';
import { Solicitacao } from '../solicitacoes/solicitacao.entity';

@Injectable()
export class ProgressoCaronaService {
  constructor(private readonly dataSource: DataSource) {}

  private pontos(manager: EntityManager, idCarona: number) {
    return manager.getRepository(PontoEmbarque).find({
      where: { carona: { idCarona } },
      order: { ordem: 'ASC', idPontoEmbarque: 'ASC' },
    });
  }

  async consultar(idCarona: number, idUsuario: number) {
    const manager = this.dataSource.manager;
    const carona = await manager.getRepository(Carona).findOne({
      where: { idCarona },
      relations: { usuario: true },
    });
    if (!carona) throw new NotFoundException('Carona não encontrada');
    if (
      carona.usuario.idUsuario !== idUsuario &&
      !(await manager.getRepository(Solicitacao).exists({
        where: {
          carona: { idCarona },
          passageiro: { idUsuario },
          status: 'ACEITA',
        },
      }))
    ) {
      throw new ForbiddenException('Você não pode acompanhar esta corrida');
    }
    return this.pontos(manager, idCarona);
  }

  async marcar(idCarona: number, idPonto: number, idUsuario: number) {
    return this.dataSource.transaction(async (manager) => {
      // Serializa marcações simultâneas para preservar a ordem do percurso.
      const carona = await manager.getRepository(Carona).findOne({
        where: { idCarona, usuario: { idUsuario } },
        lock: { mode: 'pessimistic_write' },
      });
      if (!carona) throw new NotFoundException('Carona não encontrada');
      if (carona.status !== 'EM_ANDAMENTO') {
        throw new ConflictException(
          'Somente corridas em andamento podem registrar pontos',
        );
      }
      const pontos = await this.pontos(manager, idCarona);
      const ponto = pontos.find((p) => p.idPontoEmbarque === idPonto);
      if (!ponto)
        throw new NotFoundException('Ponto não pertence a esta carona');
      if (ponto.percorridoEm) return pontos;
      if (pontos.find((p) => !p.percorridoEm)?.idPontoEmbarque !== idPonto) {
        throw new ConflictException(
          'Registre primeiro o próximo ponto do percurso',
        );
      }
      ponto.percorridoEm = new Date();
      await manager.getRepository(PontoEmbarque).save(ponto);
      return pontos;
    });
  }
}
