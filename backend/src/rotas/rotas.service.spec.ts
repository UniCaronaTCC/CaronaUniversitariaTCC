import { BadGatewayException } from '@nestjs/common';
import { RotasService } from './rotas.service';

describe('RotasService', () => {
  const respostaValida = {
    features: [
      {
        geometry: {
          coordinates: [
            [-50.4, -21.2],
            [-50.3, -21.3],
          ],
        },
        properties: { summary: { distance: 1200, duration: 300 } },
      },
    ],
  };

  beforeEach(() => {
    process.env.OPENROUTESERVICE_API_KEY = 'chave-de-teste';
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('tenta novamente após erro temporário', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce({ ok: false, status: 504 } as Response)
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => respostaValida,
      } as Response);

    const resultado = await new RotasService().calcularRota([
      [-50.4, -21.2],
      [-50.3, -21.3],
    ]);

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(resultado.distanciaMetros).toBe(1200);
  });

  it('não repete erro permanente', async () => {
    const fetchMock = jest
      .spyOn(global, 'fetch')
      .mockResolvedValue({ ok: false, status: 400 } as Response);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);

    await expect(
      new RotasService().calcularRota([
        [-50.4, -21.2],
        [-50.3, -21.3],
      ]),
    ).rejects.toBeInstanceOf(BadGatewayException);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
