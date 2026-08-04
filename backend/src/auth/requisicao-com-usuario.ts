import { Request } from 'express';

export interface UsuarioToken {
  sub: number;
  email: string;
  nome: string;
}

export interface RequisicaoComUsuario extends Request {
  usuario: UsuarioToken;
}
