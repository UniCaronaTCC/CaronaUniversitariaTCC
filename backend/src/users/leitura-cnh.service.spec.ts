import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { tmpdir } from 'node:os';
import sharp from 'sharp';
import { createWorker } from 'tesseract.js';

import { LeituraCnhService } from './leitura-cnh.service';

jest.mock('tesseract.js', () => ({ createWorker: jest.fn() }));

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

  it('processa as duas fotos e encerra o worker', async () => {
    const processadas: Buffer[] = [];
    const recognize = jest.fn((imagem: Buffer) => {
      processadas.push(imagem);
      const text = processadas.length === 1 ? 'FRENTE' : 'VERSO';
      return Promise.resolve({ data: { text } });
    });
    const worker = {
      recognize,
      terminate: jest.fn().mockResolvedValue(undefined),
    };
    jest.mocked(createWorker).mockResolvedValue(worker as never);

    const imagem = await criarImagem(900, 600);
    await expect(service.ler(imagem, imagem)).resolves.toBe('FRENTE\nVERSO');
    expect(createWorker).toHaveBeenCalledWith('por', undefined, {
      cachePath: tmpdir(),
    });
    expect(worker.recognize).toHaveBeenCalledTimes(2);
    expect(worker.terminate).toHaveBeenCalledTimes(1);
    expect(processadas[0].every((byte) => byte === 0)).toBe(true);
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
