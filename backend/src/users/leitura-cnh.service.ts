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
import { rotulosCnhLocalizados } from './campos-cnh-layout';

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
          let leitura: LeituraCnh = {
            texto: '',
            nome: null,
            campos: { cpf: null, validade: null, categoria: null },
          };
          // Só tentamos outras orientações quando faltam os rótulos do
          // documento. Todas as leituras usam o mesmo worker e a mesma foto.
          for (const angulo of [0, 270, 90, 180]) {
            const orientada = angulo
              ? await sharp(frentePreparada).rotate(angulo).png().toBuffer()
              : frentePreparada;
            try {
              await worker.setParameters({
                tessedit_pageseg_mode: PSM.AUTO,
                thresholding_method: '2',
              });
              const resultado = await worker.recognize(
                orientada,
                {},
                { text: true, blocks: true },
              );
              if (angulo === 0) leitura.texto = resultado.data.text;
              if (!rotulosCnhLocalizados(resultado.data.blocks)) continue;
              leitura = {
                texto: resultado.data.text,
                ...(await lerCamposCnh(
                  worker,
                  orientada,
                  resultado.data.blocks,
                  (diagnostico) =>
                    this.logger.log(
                      `CNH: diagnostico_campo ${JSON.stringify(diagnostico)}`,
                    ),
                )),
              };
              break;
            } finally {
              if (angulo) orientada.fill(0);
            }
          }
          this.logger.log(
            `CNH: campos_lidos ${JSON.stringify({
              nome: !!leitura.nome,
              cpf: !!leitura.campos?.cpf,
              validade: !!leitura.campos?.validade,
              categoria: !!leitura.campos?.categoria,
            })}`,
          );
          return leitura;
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
        Math.max(metadados.width, metadados.height) < 600 ||
        Math.min(metadados.width, metadados.height) < 400
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
