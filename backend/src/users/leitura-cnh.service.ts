import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { createWorker } from 'tesseract.js';
import { nomePeloLayout, type LeituraCnh } from './nome-cnh-layout';

@Injectable()
export class LeituraCnhService {
  private leiturasEmAndamento = 0;

  async ler(frente: Buffer, verso: Buffer): Promise<LeituraCnh> {
    if (this.leiturasEmAndamento >= 2) {
      throw new ServiceUnavailableException(
        'Muitas verificações em andamento. Tente novamente em instantes',
      );
    }
    this.leiturasEmAndamento++;

    let frentePreparada: Buffer | undefined;
    let versoPreparado: Buffer | undefined;

    try {
      frentePreparada = await this.preparar(frente);
      versoPreparado = await this.preparar(verso);

      try {
        const worker = await createWorker('por', undefined, {
          cachePath: tmpdir(),
        });
        try {
          const primeira = await worker.recognize(
            frentePreparada,
            {},
            { text: true, blocks: true },
          );
          const segunda = await worker.recognize(versoPreparado);
          return {
            texto: `${primeira.data.text}\n${segunda.data.text}`,
            nome: nomePeloLayout(primeira.data.blocks),
          };
        } finally {
          await worker.terminate();
        }
      } catch {
        throw new ServiceUnavailableException(
          'Não foi possível ler a CNH agora. Tente novamente mais tarde',
        );
      }
    } finally {
      frentePreparada?.fill(0);
      versoPreparado?.fill(0);
      this.leiturasEmAndamento--;
    }
  }

  private async preparar(arquivo: Buffer): Promise<Buffer> {
    try {
      const imagem = sharp(arquivo, {
        limitInputPixels: 20_000_000,
        failOn: 'error',
      });
      const metadados = await imagem.metadata();
      if (
        !metadados.width ||
        !metadados.height ||
        metadados.width < 600 ||
        metadados.height < 400
      ) {
        throw new BadRequestException('Envie fotos maiores e mais nítidas');
      }

      return await imagem
        .rotate()
        .resize({ width: 2600, withoutEnlargement: true })
        .grayscale()
        .normalise()
        .sharpen()
        .png()
        .toBuffer();
    } catch (erro) {
      if (erro instanceof BadRequestException) throw erro;
      throw new BadRequestException('Foto inválida ou grande demais');
    }
  }
}
