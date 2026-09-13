# UniCarona

[![CI Backend e Flutter](https://github.com/UniCaronaTCC/CaronaUniversitariaTCC/actions/workflows/ci.yml/badge.svg?branch=desenvolvimento)](https://github.com/UniCaronaTCC/CaronaUniversitariaTCC/actions/workflows/ci.yml)

Aplicativo de caronas universitÃ¡rias desenvolvido como Trabalho de ConclusÃ£o
de Curso. O projeto permite publicar e buscar caronas, solicitar vagas,
organizar pontos de embarque e avaliar os participantes.

## Tecnologias

- Flutter e Dart no aplicativo mÃ³vel.
- Node.js, TypeScript e NestJS no backend.
- PostgreSQL, TypeORM e Supabase.

## Estrutura

```text
.
|-- frontend/
|-- backend/
`-- .github/workflows/ci.yml
```

## Testes e integraÃ§Ã£o contÃ­nua

Os testes unitÃ¡rios do backend utilizam Jest e ficam junto aos arquivos
testados, dentro de `backend/src`.

O workflow de integraÃ§Ã£o contÃ­nua Ã© executado em pushes e pull requests para
as branches `master` e `desenvolvimento`. Ele instala as dependÃªncias, executa
os testes unitÃ¡rios e faz o build do backend.

Para executar as mesmas verificaÃ§Ãµes localmente:

```bash
cd backend
npm ci
npm test -- --runInBand
npm run build
```

## Testes do aplicativo

```bash
cd frontend
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
```
