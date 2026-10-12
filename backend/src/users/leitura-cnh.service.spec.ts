import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { createWorker } from 'tesseract.js';
import type { Block } from 'tesseract.js';

import { LeituraCnhService } from './leitura-cnh.service';

jest.mock('tesseract.js', () => ({
  createWorker: jest.fn(),
  PSM: { AUTO: '3' },
}));

describe('LeituraCnhService', () => {
  const service = new LeituraCnhService();
  const criarImagem = (width: number, height: number) =>
    sharp({
      create: {
        width,
        height,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();

  beforeEach(() => jest.resetAllMocks());

  it('valida as duas fotos, lê os campos da frente e encerra o worker', async () => {
    const processadas: Buffer[] = [];
    const recognize = jest.fn((imagem: Buffer) => {
      processadas.push(imagem);
      const text = processadas.length === 1 ? 'FRENTE' : 'VERSO';
      return Promise.resolve({ data: { text } });
    });
    const worker = {
      recognize,
      setParameters: jest.fn().mockResolvedValue(undefined),
      terminate: jest.fn().mockResolvedValue(undefined),
    };
    jest.mocked(createWorker).mockResolvedValue(worker as never);

    const imagem = await criarImagem(900, 600);
    await expect(service.ler(imagem, imagem)).resolves.toEqual({
      texto: 'FRENTE',
      nome: null,
      campos: { cpf: null, validade: null, categoria: null },
    });
    expect(worker.recognize).toHaveBeenNthCalledWith(
      1,
      processadas[0],
      {},
      { text: true, blocks: true },
    );
    expect(createWorker).toHaveBeenCalledWith('por', undefined, {
      cachePath: tmpdir(),
    });
    expect(worker.recognize).toHaveBeenCalledTimes(4);
    expect(worker.setParameters).toHaveBeenCalledWith({
      tessedit_pageseg_mode: '3',
      thresholding_method: '2',
    });
    expect(worker.terminate).toHaveBeenCalledTimes(1);
    expect(
      processadas.every((imagem) => imagem.every((byte) => byte === 0)),
    ).toBe(true);
  });

  it.each([1, 2, 3, 4])(
    'encontra rótulos na tentativa %i sem criar outro worker',
    async (tentativa) => {
      const palavras = ['NOME', 'CPF', 'VALIDADE'].map((text, i) => ({
        text,
        bbox: { x0: 100 + i * 250, x1: 150 + i * 250, y0: 10, y1: 20 },
      }));
      const blocks = [
        { paragraphs: [{ lines: [{ words: palavras }] }] },
      ] as unknown as Block[];
      const processadas: Buffer[] = [];
      const worker = {
        recognize: jest.fn((imagem: Buffer) => {
          processadas.push(imagem);
          return Promise.resolve({
            data: {
              text: 'CNH',
              blocks: processadas.length === tentativa ? blocks : null,
            },
          });
        }),
        setParameters: jest.fn().mockResolvedValue(undefined),
        terminate: jest.fn().mockResolvedValue(undefined),
      };
      jest.mocked(createWorker).mockResolvedValue(worker as never);
      const imagem = await criarImagem(900, 600);
      await service.ler(imagem, imagem);
      expect(worker.recognize).toHaveBeenCalledTimes(tentativa);
      expect(createWorker).toHaveBeenCalledTimes(1);
      expect(worker.terminate).toHaveBeenCalledTimes(1);
      expect(
        processadas.every((foto) => foto.every((byte) => byte === 0)),
      ).toBe(true);
    },
  );

  it('aceita dimensão mínima também quando a foto é vertical', async () => {
    const worker = {
      recognize: jest
        .fn()
        .mockResolvedValue({ data: { text: '', blocks: null } }),
      setParameters: jest.fn().mockResolvedValue(undefined),
      terminate: jest.fn().mockResolvedValue(undefined),
    };
    jest.mocked(createWorker).mockResolvedValue(worker as never);
    const imagem = await criarImagem(400, 600);
    await expect(service.ler(imagem, imagem)).resolves.toHaveProperty(
      'nome',
      null,
    );
    expect(worker.terminate).toHaveBeenCalledTimes(1);
  });

  it('rejeita imagem pequena antes de iniciar o OCR', async () => {
    const pequena = await criarImagem(300, 200);
    await expect(service.ler(pequena, pequena)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(createWorker).not.toHaveBeenCalled();
  });

  it('não trata indisponibilidade do OCR como recusa da CNH', async () => {
    jest
      .mocked(createWorker)
      .mockRejectedValue(new Error('sem dados de idioma'));
    const imagem = await criarImagem(900, 600);
    await expect(service.ler(imagem, imagem)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('limita verificações simultâneas para não esgotar o servidor', async () => {
    const worker = {
      setParameters: jest.fn().mockResolvedValue(undefined),
      recognize: jest.fn().mockResolvedValue({ data: { text: 'CNH' } }),
      terminate: jest.fn().mockResolvedValue(undefined),
    };
    jest.mocked(createWorker).mockResolvedValue(worker as never);
    const imagem = await criarImagem(900, 600);

    const primeira = service.ler(imagem, imagem);
    const segunda = service.ler(imagem, imagem);
    await expect(service.ler(imagem, imagem)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    await Promise.all([primeira, segunda]);
    expect(createWorker).toHaveBeenCalledTimes(2);
  });
});
