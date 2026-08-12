import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Like, Repository } from 'typeorm';

import { InstituicaoCampus } from './instituicao-campus.entity';
import { Instituicao } from './instituicao.entity';

export interface InstituicaoEncontrada {
  instituicao: Instituicao;
  campus: InstituicaoCampus;
  distanciaKm: number | null;
}

@Injectable()
export class InstituicoesService {
  constructor(
    @InjectRepository(Instituicao)
    private readonly instituicoesRepository: Repository<Instituicao>,
    @InjectRepository(InstituicaoCampus)
    private readonly campiRepository: Repository<InstituicaoCampus>,
  ) {}

  async buscar(
    termo: string,
    cidade?: string,
    uf?: string,
    latitude?: number,
    longitude?: number,
  ): Promise<InstituicaoEncontrada[]> {
    const busca = termo.replace(/[%_]/g, '').trim();

    if (busca.length < 2) {
      return [];
    }

    const instituicaoExata = await this.instituicoesRepository.findOne({
      where: [
        { nome: busca, ativa: true },
        { sigla: busca, ativa: true },
      ],
    });

    const instituicoes = await this.instituicoesRepository.find({
      where: [
        { nome: Like(`%${busca}%`), ativa: true },
        { sigla: Like(`%${busca}%`), ativa: true },
      ],
      order: {
        nome: 'ASC',
        municipio: 'ASC',
      },
      take: 30,
    });

    if (
      instituicaoExata &&
      !instituicoes.some(
        (item) => item.idInstituicao === instituicaoExata.idInstituicao,
      )
    ) {
      instituicoes.push(instituicaoExata);
    }

    if (instituicoes.length === 0) {
      return [];
    }

    const ids = instituicoes.map((item) => item.idInstituicao);
    const campi = await this.campiRepository.find({
      where: {
        idInstituicao: In(ids),
        ativo: true,
      },
    });

    const resultados = instituicoes.flatMap((instituicao) => {
      const campiDaInstituicao = campi.filter(
        (campus) => campus.idInstituicao === instituicao.idInstituicao,
      );

      if (campiDaInstituicao.length === 0) {
        campiDaInstituicao.push(
          this.campiRepository.create({
            idInstituicao: instituicao.idInstituicao,
            nome: instituicao.municipio,
            municipio: instituicao.municipio,
            uf: instituicao.uf,
            ativo: true,
          }),
        );
      }

      return campiDaInstituicao.map((campus) => ({
        instituicao,
        campus,
        distanciaKm: this.calcularDistancia(
          latitude,
          longitude,
          campus.latitude,
          campus.longitude,
        ),
      }));
    });

    resultados.sort((primeiro, segundo) => {
      const primeiroExato = this.ehBuscaExata(primeiro.instituicao, busca);
      const segundoExato = this.ehBuscaExata(segundo.instituicao, busca);

      if (primeiroExato !== segundoExato) {
        return primeiroExato ? -1 : 1;
      }

      const diferencaLocal =
        this.pontuarLocal(primeiro, cidade, uf) -
        this.pontuarLocal(segundo, cidade, uf);

      if (diferencaLocal !== 0) {
        return diferencaLocal;
      }

      return primeiro.instituicao.nome.localeCompare(
        segundo.instituicao.nome,
        'pt-BR',
      );
    });

    return resultados.slice(0, 10);
  }

  async buscarPorId(idInstituicao: number): Promise<Instituicao | null> {
    return this.instituicoesRepository.findOne({
      where: { idInstituicao, ativa: true },
    });
  }

  async campusValido(
    idInstituicao: number,
    nomeCampus: string,
  ): Promise<boolean> {
    const campus = await this.campiRepository.findOne({
      where: {
        idInstituicao,
        nome: nomeCampus,
        ativo: true,
      },
    });

    return campus != null;
  }

  private ehBuscaExata(instituicao: Instituicao, busca: string): boolean {
    const termo = this.normalizar(busca);

    return (
      this.normalizar(instituicao.nome) === termo ||
      this.normalizar(instituicao.sigla ?? '') === termo
    );
  }

  private pontuarLocal(
    resultado: InstituicaoEncontrada,
    cidade?: string,
    uf?: string,
  ): number {
    if (
      cidade &&
      this.normalizar(resultado.campus.municipio) === this.normalizar(cidade)
    ) {
      return resultado.distanciaKm ?? 0;
    }

    if (resultado.distanciaKm != null) {
      return resultado.distanciaKm;
    }

    if (uf && resultado.campus.uf.toUpperCase() === uf.toUpperCase()) {
      return 10000;
    }

    return 20000;
  }

  private calcularDistancia(
    latitudeUsuario?: number,
    longitudeUsuario?: number,
    latitudeCampus?: string | null,
    longitudeCampus?: string | null,
  ): number | null {
    if (latitudeCampus == null || longitudeCampus == null) {
      return null;
    }

    const latitudeDestino = Number(latitudeCampus);
    const longitudeDestino = Number(longitudeCampus);

    if (
      !Number.isFinite(latitudeUsuario) ||
      !Number.isFinite(longitudeUsuario) ||
      !Number.isFinite(latitudeDestino) ||
      !Number.isFinite(longitudeDestino)
    ) {
      return null;
    }

    const radianos = Math.PI / 180;
    const diferencaLatitude = (latitudeDestino - latitudeUsuario!) * radianos;
    const diferencaLongitude =
      (longitudeDestino - longitudeUsuario!) * radianos;
    const a =
      Math.sin(diferencaLatitude / 2) ** 2 +
      Math.cos(latitudeUsuario! * radianos) *
        Math.cos(latitudeDestino * radianos) *
        Math.sin(diferencaLongitude / 2) ** 2;

    return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private normalizar(texto: string): string {
    return texto
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .trim()
      .toLowerCase();
  }
}
