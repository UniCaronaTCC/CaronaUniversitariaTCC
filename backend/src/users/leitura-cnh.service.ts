import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { createWorker, PSM } from 'tesseract.js';
import { type LeituraCnh } from './nome-cnh-layout';
import { lerCamposCnh } from './ler-campos-cnh';

@Injectable()
export class LeituraCnhService {
  private readonly logger = new Logger(LeituraCnhService.name);
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
          await worker.setParameters({
            tessedit_pageseg_mode: PSM.AUTO,
            thresholding_method: '2',
          });
          const primeira = await worker.recognize(
            frentePreparada,
            {},
            { text: true, blocks: true },
          );
          const campos = await lerCamposCnh(
            worker,
            frentePreparada,
            primeira.data.blocks,
          );
          this.logger.log(
            `CNH: campos_lidos ${JSON.stringify({
              nome: !!campos.nome,
              cpf: !!campos.campos?.cpf,
              validade: !!campos.campos?.validade,
              categoria: !!campos.campos?.categoria,
            })}`,
          );
          return {
            texto: primeira.data.text,
            ...campos,
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
        .png()
        .toBuffer();
    } catch (erro) {
      if (erro instanceof BadRequestException) throw erro;
      throw new BadRequestException('Foto inválida ou grande demais');
    }
  }
}
