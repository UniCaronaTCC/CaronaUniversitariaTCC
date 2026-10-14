import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, LessThan, Repository } from 'typeorm';
import { Notificacao } from './notificacao.entity';

@Injectable()
export class NotificacoesService {
  constructor(
    @InjectRepository(Notificacao)
    private readonly repository: Repository<Notificacao>,
  ) {}

  contar(idUsuario: number) {
    return this.repository.count({ where: { idUsuario, lidaEm: IsNull() } });
  }

  async listar(idUsuario: number, antesDe?: number) {
    const itens = await this.repository.find({
      where: {
        idUsuario,
        ...(antesDe === undefined ? {} : { id: LessThan(antesDe) }),
      },
      order: { id: 'DESC' },
      take: 51,
    });
    const temMais = itens.length > 50;
    const pagina = itens.slice(0, 50);
    return {
      itens: pagina.map((item) => ({
        id: item.id,
        tipo: item.tipo,
        titulo: item.titulo,
        descricao: item.descricao,
        referencias: item.referencias,
        criadoEm: item.criadoEm,
        lidaEm: item.lidaEm,
      })),
      totalNaoLidas: await this.contar(idUsuario),
      temMais,
      proximoAntesDe: temMais ? pagina[pagina.length - 1].id : null,
    };
  }

  async abrir(idUsuario: number) {
    // Uma unica atualizacao marca apenas as linhas visiveis neste instante.
    await this.repository.update(
      { idUsuario, lidaEm: IsNull() },
      { lidaEm: new Date() },
    );
    return this.listar(idUsuario);
  }
}
