import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('instituicoes')
@Index(['nome'])
@Index(['sigla'])
export class Instituicao {
  @PrimaryGeneratedColumn({ name: 'id_instituicao' })
  idInstituicao: number;

  @Column({ name: 'codigo_emec', type: 'int', unique: true })
  codigoEmec: number;

  @Column({ type: 'varchar', length: 255 })
  nome: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  sigla: string | null = null;

  @Column({ type: 'varchar', length: 100 })
  municipio: string;

  @Column({ type: 'char', length: 2 })
  uf: string;

  @Column({ type: 'boolean', default: true })
  ativa: boolean = true;
}
