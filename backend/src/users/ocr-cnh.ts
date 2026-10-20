// Estrutura interna independente do mecanismo de OCR.
export interface Bbox {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}
export interface Word {
  text: string;
  bbox: Bbox;
}
export interface Block {
  paragraphs: { lines: { words: Word[] }[] }[];
}
