import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('instituicoes_campi')
@Index(['idInstituicao', 'nome', 'municipio', 'uf'], { unique: true })
export class InstituicaoCampus {
  @PrimaryGeneratedColumn({ name: 'id_campus' })
  idCampus: number;

  @Column({ name: 'id_instituicao', type: 'int' })
  idInstituicao: number;

  @Column({ type: 'varchar', length: 150 })
  nome: string;

  @Column({ type: 'varchar', length: 100 })
  municipio: string;

  @Column({ type: 'char', length: 2 })
  uf: string;

  @Column({ type: 'decimal', precision: 10, scale: 8, nullable: true })
  latitude: string | null = null;

  @Column({ type: 'decimal', precision: 11, scale: 8, nullable: true })
  longitude: string | null = null;

  @Column({ type: 'boolean', default: true })
  ativo: boolean = true;
}
