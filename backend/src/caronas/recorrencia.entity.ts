import {
  Column,
  CreateDateColumn,
  Entity,
  OneToMany,
  PrimaryGeneratedColumn,
} from 'typeorm';
import type { DadosCriacaoCarona } from './dados-carona';
import { numeroDecimalTransformer } from '../database/numero-decimal.transformer';
import { PontoEmbarqueRecorrencia } from './ponto-embarque-recorrencia.entity';
import { DIAS_SEMANA } from './datas-recorrencia';

// A programação guarda somente os dados de oferta, nunca passageiros ou GPS.
@Entity('recorrencias_carona')
export class RecorrenciaCarona {
  @PrimaryGeneratedColumn({ name: 'id_recorrencia' })
  idRecorrencia!: number;

  @Column({ name: 'id_usuario', type: 'int' })
  idUsuario!: number;

  @Column({ default: true })
  ativa: boolean = true;

  @Column({ length: 255 })
  origem!: string;
  @Column({
    name: 'origem_cidade',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  origemCidade: string | null = null;
  @Column({
    name: 'origem_latitude',
    type: 'decimal',
    precision: 10,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  origemLatitude!: number;
  @Column({
    name: 'origem_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  origemLongitude!: number;
  @Column({ length: 255 })
  destino!: string;
  @Column({
    name: 'destino_cidade',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  destinoCidade: string | null = null;
  @Column({
    name: 'destino_latitude',
    type: 'decimal',
    precision: 10,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  destinoLatitude!: number;
  @Column({
    name: 'destino_longitude',
    type: 'decimal',
    precision: 11,
    scale: 8,
    transformer: numeroDecimalTransformer,
  })
  destinoLongitude!: number;
  @Column({ name: 'data_inicio', type: 'date' })
  dataInicio!: string;
  @Column({ name: 'data_fim', type: 'date', nullable: true })
  dataFim: string | null = null;
  @Column({ type: 'time' })
  horario!: string;
  @Column({ name: 'dias_semana', type: 'smallint', array: true })
  diasSemana!: number[];
  @Column({ type: 'int' })
  vagas!: number;
  @Column({
    type: 'decimal',
    precision: 10,
    scale: 2,
    transformer: numeroDecimalTransformer,
  })
  valor!: number;
  @Column({ type: 'text', nullable: true })
  observacoes: string | null = null;
  @CreateDateColumn({ name: 'criado_em', type: 'timestamptz' })
  criadoEm!: Date;

  @OneToMany(() => PontoEmbarqueRecorrencia, (ponto) => ponto.recorrencia, {
    cascade: ['insert'],
  })
  pontosEmbarque!: PontoEmbarqueRecorrencia[];

  definirDados(dados: Omit<DadosCriacaoCarona, 'idUsuario'>) {
    const { recorrente, diasSemana, pontosEmbarque, ...campos } = dados;
    if (!recorrente) throw new Error('A programação precisa ser recorrente');
    Object.assign(this, campos);
    this.observacoes = dados.observacoes ?? null;
    this.diasSemana = (diasSemana ?? []).map(
      (dia) => DIAS_SEMANA.indexOf(dia) || 7,
    );
    this.pontosEmbarque = pontosEmbarque.map((ponto) =>
      Object.assign(new PontoEmbarqueRecorrencia(), ponto),
    );
  }

  // Formato de transporte para o app e para a geração; não é coluna JSON.
  get dados(): Omit<DadosCriacaoCarona, 'idUsuario'> {
    return {
      origem: this.origem,
      origemCidade: this.origemCidade,
      origemLatitude: this.origemLatitude,
      origemLongitude: this.origemLongitude,
      destino: this.destino,
      destinoCidade: this.destinoCidade,
      destinoLatitude: this.destinoLatitude,
      destinoLongitude: this.destinoLongitude,
      dataInicio: this.dataInicio,
      dataFim: this.dataFim,
      horario: this.horario,
      vagas: this.vagas,
      valor: this.valor,
      observacoes: this.observacoes ?? undefined,
      recorrente: true,
      diasSemana: this.diasSemana.map((dia) => DIAS_SEMANA[dia % 7]),
      pontosEmbarque: [...this.pontosEmbarque]
        .sort((a, b) => a.ordem - b.ordem)
        .map((p) => ({
          nome: p.nome,
          endereco: p.endereco,
          latitude: p.latitude,
          longitude: p.longitude,
          ordem: p.ordem,
        })),
    };
  }
}
