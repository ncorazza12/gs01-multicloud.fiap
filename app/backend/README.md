# GS01 Backend API

Node.js + Express API for the GS01 multicloud demo. The same image runs on AWS EKS; `CLOUD_NAME` identifies the cloud in every API response.

## Environment

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `DATABASE_URL` | yes | - | CockroachDB/Postgres connection string |
| `CLOUD_NAME` | no | `unknown` | `aws` |
| `FRONTEND_ORIGIN` | no | `*` | CORS origin |
| `PORT` | no | `3000` | HTTP listen port |

## Local Run

```bash
npm install
DATABASE_URL="postgresql://..." CLOUD_NAME=local npm start
```

## Docker

```bash
docker login ghcr.io -u ncorazza12
docker build -t ghcr.io/ncorazza12/gs01-multicloud.fiap/gs01-api:v1 .
docker push ghcr.io/ncorazza12/gs01-multicloud.fiap/gs01-api:v1
```

## Endpoints

| Method | Path | Body | Response |
| --- | --- | --- | --- |
| `GET` | `/health` | - | `{ ok: true, cloud }` |
| `GET` | `/api/subjects` | - | `{ data: Subject[], cloud }` |
| `POST` | `/api/subjects` | `{ "name": "..." }` | `{ data: Subject, cloud }` |
| `PATCH` | `/api/subjects/:id` | - | `{ data: Subject, cloud }` |
| `DELETE` | `/api/subjects/:id` | - | `{ cloud }` |
