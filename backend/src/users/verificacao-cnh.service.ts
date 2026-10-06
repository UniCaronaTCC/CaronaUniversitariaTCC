import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';

import { extrairDadosCnh } from './dados-cnh';
import { LeituraCnhService } from './leitura-cnh.service';
import { User } from './user.entity';
import { cnhPermiteOferecerCarona } from './verificacao-cnh';

export function hojeEmSaoPaulo(agora = new Date()): string {
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(agora);
  const obter = (tipo: string) =>
    partes.find((parte) => parte.type === tipo)!.value;
  return `${obter('year')}-${obter('month')}-${obter('day')}`;
}

@Injectable()
export class VerificacaoCnhService {
  private readonly emAndamento = new Set<number>();

  constructor(
    @InjectRepository(User)
    private readonly usuarios: Repository<User>,
    private readonly leitura: LeituraCnhService,
  ) {}

  async verificar(idUsuario: number, frente: Buffer, verso: Buffer) {
    if (this.emAndamento.has(idUsuario)) {
      throw new ConflictException('Já existe uma verificação em andamento');
    }
    this.emAndamento.add(idUsuario);

    try {
      const usuario = await this.usuarios.findOne({ where: { idUsuario } });
      if (!usuario) throw new NotFoundException('Usuário não encontrado');

      const hoje = hojeEmSaoPaulo();
      if (cnhPermiteOferecerCarona(usuario, hoje)) {
        return { status: 'APROVADA' as const };
      }

      const texto = await this.leitura.ler(frente, verso);
      const dados = extrairDadosCnh(texto, usuario.nome, hoje);
      const privacidadeAceitaEm = new Date();

      if (!dados) {
        await this.usuarios.update(idUsuario, {
          statusVerificacaoCnh: 'RECUSADA',
          cpf: null,
          cnhCategoria: null,
          cnhValidade: null,
          cnhRegistroFinal: null,
          cnhVerificadaEm: null,
          privacidadeAceitaEm,
        });
        return { status: 'RECUSADA' as const };
      }

      try {
        await this.usuarios.update(idUsuario, {
          statusVerificacaoCnh: 'APROVADA',
          cpf: dados.cpf,
          cnhCategoria: dados.categoria,
          cnhValidade: dados.validade,
          cnhRegistroFinal: dados.registroFinal,
          cnhVerificadaEm: new Date(),
          privacidadeAceitaEm,
        });
      } catch (erro) {
        const detalhe =
          erro instanceof QueryFailedError
            ? (erro.driverError as { code?: string; constraint?: string })
            : null;
        if (
          detalhe?.code === '23505' &&
          detalhe.constraint === 'uq_usuarios_cpf'
        ) {
          throw new ConflictException(
            'Este documento já está associado a outra conta',
          );
        }
        throw erro;
      }

      return { status: 'APROVADA' as const };
    } finally {
      this.emAndamento.delete(idUsuario);
    }
  }
}
