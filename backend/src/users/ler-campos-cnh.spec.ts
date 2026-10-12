import sharp from 'sharp';
import type { Block, Worker } from 'tesseract.js';
import { lerCamposCnh } from './ler-campos-cnh';
import { conferirDadosCnh } from './dados-cnh';

const palavra = (text: string, x: number, y: number) => ({
  text,
  bbox: { x0: x, x1: x + 60, y0: y, y1: y + 10 },
});

describe('releitura de campos ancorados', () => {
  it('não relê uma região sem rótulo', async () => {
    const imagem = await sharp({
      create: { width: 900, height: 600, channels: 3, background: 'white' },
    })
      .png()
      .toBuffer();
    const worker = { recognize: jest.fn(), setParameters: jest.fn() };
    await expect(
      lerCamposCnh(worker as unknown as Worker, imagem, null),
    ).resolves.toEqual({
      nome: null,
      campos: { cpf: null, validade: null, categoria: null },
    });
    expect(worker.recognize).not.toHaveBeenCalled();
  });

  it('lê nome no recorte confirmado sem exigir rótulo novamente e mantém comparação integral', async () => {
    const imagem = await sharp({
      create: { width: 900, height: 600, channels: 3, background: 'white' },
    })
      .png()
      .toBuffer();
    const blocks = [
      {
        paragraphs: [
          {
            lines: [
              { words: [palavra('NOME', 100, 10)] },
              {
                words: [palavra('MARIA?', 100, 30), palavra('SILVA', 170, 30)],
              },
            ],
          },
        ],
      },
    ] as unknown as Block[];
    const recortes: Buffer[] = [];
    const worker = {
      recognize: jest.fn((foto: Buffer) => {
        recortes.push(foto);
        return Promise.resolve({ data: { text: 'MARIA SILVA' } });
      }),
      setParameters: jest.fn().mockResolvedValue(undefined),
    };
    const leitura = await lerCamposCnh(
      worker as unknown as Worker,
      imagem,
      blocks,
    );
    expect(leitura.nome).toBe('MARIA SILVA');
    expect(
      conferirDadosCnh({ texto: '', ...leitura }, 'Maria Souza', '2026-10-12')
        .motivo,
    ).toBe('NOME_DIVERGENTE');
    expect(recortes.every((foto) => foto.every((byte) => byte === 0))).toBe(
      true,
    );
  });

  it('mantém o limite de duas releituras e limpa buffers também em falha', async () => {
    const imagem = await sharp({
      create: { width: 900, height: 600, channels: 3, background: 'white' },
    })
      .png()
      .toBuffer();
    const blocks = [
      {
        paragraphs: [
          {
            lines: [
              { words: [palavra('NOME', 100, 10)] },
              {
                words: [palavra('MARIA?', 100, 30), palavra('SILVA', 170, 30)],
              },
            ],
          },
        ],
      },
    ] as unknown as Block[];
    const recortes: Buffer[] = [];
    const worker = {
      recognize: jest.fn((foto: Buffer) => {
        recortes.push(foto);
        if (recortes.length === 2) throw new Error('falha de OCR');
        return Promise.resolve({ data: { text: '123' } });
      }),
      setParameters: jest.fn().mockResolvedValue(undefined),
    };
    await expect(
      lerCamposCnh(worker as unknown as Worker, imagem, blocks),
    ).rejects.toThrow('falha de OCR');
    expect(worker.recognize).toHaveBeenCalledTimes(2);
    expect(recortes.every((foto) => foto.every((byte) => byte === 0))).toBe(
      true,
    );
  });
});
