import sharp from 'sharp';
import { PSM, type Block, type Worker } from 'tesseract.js';
import { nomePeloLayout, type LeituraCnh } from './nome-cnh-layout';
import {
  regiaoDoCampo,
  valorDoCampo,
  valorDoRecorte,
  type CampoCnh,
} from './campos-cnh-layout';
import { cpfValido } from './dados-cnh';
import type {
  DiagnosticoCampoCnh,
  RelatarCampoCnh,
} from './diagnostico-campo-cnh';

export async function lerCamposCnh(
  worker: Worker,
  imagem: Buffer,
  blocos: Block[] | null,
  diagnosticar?: (diagnostico: DiagnosticoCampoCnh) => void,
): Promise<Pick<LeituraCnh, 'nome' | 'campos'>> {
  const relatar =
    (campo: CampoCnh, etapa: DiagnosticoCampoCnh['etapa']): RelatarCampoCnh =>
    (motivo) =>
      diagnosticar?.({ campo, etapa, motivo });
  const { width = 0, height = 0 } = await sharp(imagem).metadata();
  const valores = {
    nome: nomePeloLayout(blocos, ({ motivo }) =>
      diagnosticar?.({ campo: 'nome', etapa: 'LEITURA_INICIAL', motivo }),
    ),
    cpf: valorDoCampo(
      blocos,
      'cpf',
      width,
      height,
      relatar('cpf', 'LEITURA_INICIAL'),
    ),
    validade: valorDoCampo(
      blocos,
      'validade',
      width,
      height,
      relatar('validade', 'LEITURA_INICIAL'),
    ),
    categoria: valorDoCampo(
      blocos,
      'categoria',
      width,
      height,
      relatar('categoria', 'LEITURA_INICIAL'),
    ),
  };
  // Um recorte por campo, com até duas leituras de contraste no mesmo worker.
  for (const campo of Object.keys(valores) as CampoCnh[]) {
    if (
      valores[campo] &&
      (campo !== 'cpf' || cpfValido(valores.cpf!.replace(/\D/g, '')))
    )
      continue;
    if (campo === 'cpf' && valores.cpf)
      relatar(campo, 'LEITURA_INICIAL')('CPF_INVALIDO');
    const regiao = regiaoDoCampo(
      blocos,
      campo,
      width,
      height,
      true,
      relatar(campo, 'LOCALIZACAO_RECORTE'),
    );
    if (!regiao) continue;
    let recorte: Buffer | undefined;
    try {
      let preparo = sharp(imagem)
        .extract(regiao)
        .resize({ width: Math.min(1800, regiao.width * 4) });
      preparo = preparo.extend({
        top: 10,
        bottom: 10,
        left: 10,
        right: 10,
        background: 'white',
      });
      if (campo === 'categoria')
        preparo = preparo.extractChannel(0).normalise();
      recorte = await preparo.png().toBuffer();
      await worker.setParameters({
        tessedit_pageseg_mode:
          campo === 'nome' ? PSM.SINGLE_BLOCK : PSM.SINGLE_LINE,
        thresholding_method: campo === 'nome' ? '0' : '2',
      });
      const leitura = await worker.recognize(recorte);
      let valor = valorDoRecorte(
        leitura.data.text,
        campo,
        true,
        relatar(campo, 'RELEITURA'),
      );
      if (!valor || (campo === 'cpf' && !cpfValido(valor.replace(/\D/g, '')))) {
        let contraste: Buffer | undefined;
        try {
          contraste = await sharp(recorte)
            .extractChannel(campo === 'validade' ? 1 : 0)
            .normalise()
            .png()
            .toBuffer();
          await worker.setParameters({
            tessedit_pageseg_mode:
              campo === 'nome' ? PSM.SINGLE_BLOCK : PSM.SINGLE_LINE,
            thresholding_method: '0',
          });
          const segunda = await worker.recognize(contraste);
          valor = valorDoRecorte(
            segunda.data.text,
            campo,
            true,
            relatar(campo, 'RELEITURA'),
          );
        } finally {
          contraste?.fill(0);
        }
      }
      valores[campo] = valor;
    } finally {
      recorte?.fill(0);
    }
  }
  return {
    nome: valores.nome,
    campos: {
      cpf: valores.cpf,
      validade: valores.validade,
      categoria: valores.categoria,
    },
  };
}
