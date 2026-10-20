import {
  ConflictException,
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, QueryFailedError, Repository } from 'typeorm';
import { Carona } from '../caronas/carona.entity';
import { RecorrenciaCarona } from '../caronas/recorrencia.entity';

import { conferirDadosCnh, nomeCompletoValido } from './dados-cnh';
import { LeituraCnhService } from './leitura-cnh.service';
import { User } from './user.entity';
import { cnhPermiteOferecerCarona, hojeEmSaoPaulo } from './verificacao-cnh';

@Injectable()
export class VerificacaoCnhService {
  private readonly emAndamento = new Set<number>();
  private readonly logger = new Logger(VerificacaoCnhService.name);

  constructor(
    @InjectRepository(User)
    private readonly usuarios: Repository<User>,
    private readonly leitura: LeituraCnhService,
    private readonly dataSource: DataSource,
  ) {}

  // Recurso temporario de QA: remover junto com a rota antes da entrega.
  async reiniciarParaTeste(idUsuario: number) {
    if (this.emAndamento.has(idUsuario)) {
      throw new ConflictException(
        'Aguarde a verificação em andamento terminar',
      );
    }
    this.emAndamento.add(idUsuario);
    try {
      await this.dataSource.transaction(async (manager) => {
        const usuarios = manager.getRepository(User);
        const usuario = await usuarios.findOne({
          where: { idUsuario },
          lock: { mode: 'pessimistic_write' },
        });
        if (!usuario) throw new NotFoundException('Usuário não encontrado');
        const ofertas = await manager.getRepository(Carona).exists({
          where: {
            usuario: { idUsuario },
            status: In(['ATIVA', 'LOTADA', 'EM_ANDAMENTO']),
          },
        });
        const recorrencias = await manager
          .getRepository(RecorrenciaCarona)
          .exists({
            where: { idUsuario, ativa: true },
          });
        if (ofertas || recorrencias) {
          throw new ConflictException(
            'Finalize ou cancele suas ofertas ativas e pause as recorrências antes de reiniciar a CNH',
          );
        }
        const resultado = await usuarios.update(idUsuario, {
          statusVerificacaoCnh: 'NAO_ENVIADA',
          cpf: null,
          cnhCategoria: null,
          cnhValidade: null,
          cnhRegistroFinal: null,
          cnhVerificadaEm: null,
          privacidadeAceitaEm: null,
        });
        if (resultado.affected !== 1) {
          throw new NotFoundException('Usuário não encontrado');
        }
      });
      return { status: 'NAO_ENVIADA' as const };
    } finally {
      this.emAndamento.delete(idUsuario);
    }
  }

  async verificar(
    idUsuario: number,
    leituraOcr: unknown,
    nomeCompleto: string,
  ) {
    if (!nomeCompletoValido(nomeCompleto)) {
      throw new BadRequestException(
        'Informe seu nome completo conforme a CNH. Se o campo não aparece, atualize o app.',
      );
    }
    if (this.emAndamento.has(idUsuario)) {
      throw new ConflictException('Já existe uma verificação em andamento');
    }
    this.emAndamento.add(idUsuario);
    const inicio = Date.now();
    this.logger.log('CNH: verificação iniciada');

    try {
      const usuario = await this.usuarios.findOne({ where: { idUsuario } });
      if (!usuario) throw new NotFoundException('Usuário não encontrado');

      const hoje = hojeEmSaoPaulo();
      if (cnhPermiteOferecerCarona(usuario, hoje)) {
        return { status: 'APROVADA' as const };
      }

      const texto = this.leitura.ler(leituraOcr);
      this.logger.log('CNH: leitura concluída, conferindo campos');
      const conferencia = conferirDadosCnh(
        texto,
        nomeCompleto,
        hoje,
        (diagnostico) => {
          // Somente códigos fixos e contagens, nunca o texto do documento.
          this.logger.log(
            `CNH: diagnostico_nome ${JSON.stringify(diagnostico)}`,
          );
        },
      );
      const dados = conferencia.dados;
      const privacidadeAceitaEm = new Date();

      if (!dados) {
        this.logger.warn(`CNH: ${conferencia.motivo}`);
        await this.usuarios.update(idUsuario, {
          statusVerificacaoCnh: 'RECUSADA',
          cpf: null,
          cnhCategoria: null,
          cnhValidade: null,
          cnhRegistroFinal: null,
          cnhVerificadaEm: null,
          privacidadeAceitaEm,
        });
        return { status: 'RECUSADA' as const, motivo: conferencia.motivo };
      }

      try {
        await this.usuarios.update(idUsuario, {
          statusVerificacaoCnh: 'APROVADA',
          cpf: dados.cpf,
          cnhCategoria: dados.categoria,
          cnhValidade: dados.validade,
          cnhRegistroFinal: null,
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

      this.logger.log('CNH: dados conferidos');
      return { status: 'APROVADA' as const };
    } catch (erro) {
      this.logger.warn('CNH: verificação interrompida por falha');
      throw erro;
    } finally {
      this.emAndamento.delete(idUsuario);
      this.logger.log(
        `CNH: verificação encerrada em ${Date.now() - inicio} ms`,
      );
    }
  }
}
