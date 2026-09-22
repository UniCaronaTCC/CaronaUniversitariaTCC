# UniCarona

[![CI Backend e Flutter](https://github.com/UniCaronaTCC/CaronaUniversitariaTCC/actions/workflows/ci.yml/badge.svg?branch=desenvolvimento)](https://github.com/UniCaronaTCC/CaronaUniversitariaTCC/actions/workflows/ci.yml)

Aplicativo de caronas universitárias desenvolvido como Trabalho de Conclusão
de Curso. O projeto permite publicar e buscar caronas, solicitar vagas,
organizar pontos de embarque e avaliar os participantes.

## Tecnologias

- Flutter e Dart no aplicativo móvel.
- Node.js, TypeScript e NestJS no backend.
- PostgreSQL, TypeORM e Supabase.

## Estrutura

```text
.
|-- frontend/
|-- backend/
`-- .github/workflows/ci.yml
```

## Testes e integração contínua

Os testes unitários do backend utilizam Jest e ficam junto aos arquivos
testados, dentro de `backend/src`. Os testes do aplicativo Flutter ficam em
`frontend/test`.

O workflow de integração contínua é executado em pushes e pull requests para
as branches `master` e `desenvolvimento`. Ele instala as dependências, executa
os testes unitários, faz o build do backend e gera um APK de teste.

Para verificar o backend localmente:

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
