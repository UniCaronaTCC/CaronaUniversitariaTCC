import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm'; // Importa os decorators do TypeORM para mapear a tabela

import { User } from '../users/user.entity'; // Importa a entidade de usuário para relacionar a carona com quem criou

@Entity('caronas') // Define que esta classe representa a tabela caronas no banco
export class Carona { // Classe que representa uma carona oferecida por um motorista

  @PrimaryGeneratedColumn({ name: 'id_carona' }) // ID principal da carona
  idCarona: number;

  @Column({ length: 100 }) // Local de saída da carona
  origem: string;

  @Column({ length: 100 }) // Local de destino da carona
  destino: string;

  @Column({ name: 'data_inicio', type: 'date' }) // Data da carona ou início da recorrência
  dataInicio: string;

  @Column({ name: 'data_fim', type: 'date', nullable: true }) // Data final caso a carona seja recorrente
  dataFim: string | null;

  @Column({ type: 'time' }) // Horário de saída
  horario: string;

  @Column({ type: 'int', unsigned: true }) // Quantidade de vagas disponíveis
  vagas: number;

  @Column({ type: 'decimal', precision: 10, scale: 2 }) // Valor cobrado por passageiro
  valor: number;

  @Column({ default: false }) // Informa se a carona se repete durante a semana
  recorrente: boolean;

  @Column({ name: 'dias_semana', type: 'json', nullable: true }) // Dias em que a carona se repete
  diasSemana: string[];

  @Column({ type: 'text', nullable: true }) // Observações extras do motorista
  observacoes: string;

  @Column({ length: 30, default: 'ATIVA' }) // Status usado para controlar se aparece na busca
  status: string;

  @ManyToOne(() => User) // Relaciona muitas caronas com um usuário
  @JoinColumn({ name: 'id_usuario' }) // Usa a coluna id_usuario como chave estrangeira
  usuario: User;

  @CreateDateColumn({ name: 'criado_em' }) // Data automática de criação
  criadoEm: Date;
}