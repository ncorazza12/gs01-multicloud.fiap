# GS01 Multicloud · FIAP

**Global Solutions 01 — Cloud Computing 2026**  
Aluno: **rm562265**

Aplicação fullstack rodando em **AWS EKS**, com frontend hospedado no **Cloudflare Pages**, banco de dados **CockroachDB Serverless** e deploy contínuo via **FluxCD** (GitOps).

---

## Arquitetura

```
Usuário
  │
  ▼
Cloudflare Pages  (React 18 + Vite + TypeScript)
  │  fetch /api/subjects
  ▼
DNS Cloudflare "api-rm562265.<zona>"
  │
  ▼
AWS EKS LoadBalancer  →  Pod Node.js/Express  (CLOUD_NAME=aws)
                                  │
                                  ▼
                       CockroachDB Serverless
```

---

## Estrutura do Repositório

```
gs01-multicloud.fiap/
├── app/
│   ├── backend/                        # Node.js + Express + pg
│   │   ├── server.js                   # Rotas, startup, graceful shutdown
│   │   ├── db.js                       # Pool pg, ensureSchema, seed
│   │   ├── Dockerfile                  # Node 20 alpine
│   │   └── package.json
│   └── frontend/                       # React 18 + Vite + TypeScript + Tailwind
│       └── src/
│           ├── App.tsx
│           ├── components/
│           │   ├── AddSubjectForm.tsx   # Dialog para adicionar matéria
│           │   ├── CloudBadge.tsx       # Badge "Servido por AWS"
│           │   └── SubjectTable.tsx     # Tabela com checkbox e deletar
│           ├── hooks/
│           │   └── useSubjects.ts       # Estado + chamadas à API via axios
│           └── lib/
│               └── api.ts              # Instância axios com VITE_API_URL
├── fluxcd/
│   └── apps/
│       ├── base/
│       │   ├── namespace.yaml          # Namespace "demo"
│       │   ├── deployment.yaml         # Deployment gs01-api (imagem GHCR)
│       │   ├── service.yaml            # Service LoadBalancer porta 80→3000
│       │   ├── db-credentials.sops.yaml # Secret DATABASE_URL (SOPS + age)
│       │   └── kustomization.yaml
│       └── overlays/
│           └── aws/
│               └── kustomization.yaml  # ConfigMap CLOUD_NAME=aws
└── terraform/
    └── aws/
        ├── 00-provider.tf              # Provider AWS + Helm, locals
        ├── 01-vpc.tf                   # VPC, subnets, NAT Gateway
        ├── 02-eks.tf                   # Cluster EKS 1.31 + node group t3.medium
        └── 03-fluxcd.tf               # Helm release flux2 + flux2-sync
```

---

## Backend (`app/backend`)

API REST Node.js + Express conectada ao CockroachDB via driver `pg`.

### Endpoints

| Método | Path | Body | Resposta |
|--------|------|------|----------|
| `GET` | `/health` | — | `{ ok: true, cloud }` |
| `GET` | `/api/subjects` | — | `{ data: Subject[], cloud }` |
| `POST` | `/api/subjects` | `{ "name": "..." }` | `{ data: Subject, cloud }` |
| `PATCH` | `/api/subjects/:id` | — | `{ data: Subject, cloud }` — toggle `completed` |
| `DELETE` | `/api/subjects/:id` | — | `{ cloud }` |

### Schema do banco

```sql
CREATE TABLE IF NOT EXISTS subjects (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  name       TEXT        NOT NULL,
  completed  BOOLEAN     DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Na primeira inicialização, o banco é populado automaticamente com 8 matérias:

> Cloud Advanced Engineering, Cloud Artificial Intelligence, Cloud Database, Cloud Native Development, Cloud Security, DevOps CI CD, IT Governance, Private Cloud

### Variáveis de ambiente

| Variável | Obrigatória | Padrão | Descrição |
|----------|-------------|--------|-----------|
| `DATABASE_URL` | ✅ | — | Connection string CockroachDB |
| `CLOUD_NAME` | — | `unknown` | Retornado em todas as respostas |
| `FRONTEND_ORIGIN` | — | `*` | Origem CORS permitida |
| `PORT` | — | `3000` | Porta HTTP |

### Rodando localmente

```bash
cd app/backend
npm install
DATABASE_URL="postgresql://..." CLOUD_NAME=local npm start
```

### Build e push da imagem Docker

```bash
docker login ghcr.io -u ncorazza12
docker build -t ghcr.io/ncorazza12/gs01-multicloud.fiap/gs01-api:v1 .
docker push ghcr.io/ncorazza12/gs01-multicloud.fiap/gs01-api:v1
```

---

## Frontend (`app/frontend`)

React 18 + Vite + TypeScript + Tailwind CSS + Radix UI.

Funcionalidades:
- Lista matérias cadastradas no banco
- Exibe badge **"Servido por AWS"** com o cloud que respondeu a requisição
- Adiciona novas matérias via dialog (Radix UI)
- Marca matérias como concluídas via checkbox
- Deleta matérias com confirmação visual via toast

### Variável de ambiente

```bash
# .env.local (desenvolvimento)
VITE_API_URL=http://localhost:3000
```

Para produção (Cloudflare Pages):
```
VITE_API_URL=https://api-rm562265.<sua-zona>
```

### Rodando localmente

```bash
cd app/frontend
npm install
npm run dev
```

---

## Infraestrutura (`terraform/aws`)

| Arquivo | O que provisiona |
|---------|-----------------|
| `00-provider.tf` | Provider AWS (`~> 6.0`), Helm, locals (`project=rm562265`, `env=dev`, `region=us-east-2`) |
| `01-vpc.tf` | VPC `10.0.0.0/16`, 2 subnets privadas, 2 públicas, NAT Gateway |
| `02-eks.tf` | Cluster EKS 1.31 (`eks-rm562265-dev`), node group `t3.medium` (1–2 nós), addons coredns/kube-proxy/vpc-cni |
| `03-fluxcd.tf` | Helm releases `flux2` + `flux2-sync` apontando para este repositório com decriptação SOPS/age |

### Provisionar

```bash
cd terraform/aws
terraform init
terraform apply   # ~15–20 min
```

Após o apply, configure o kubectl:

```bash
aws eks update-kubeconfig --region us-east-2 --name eks-rm562265-dev
```

---

## GitOps com FluxCD

O FluxCD é instalado via Terraform e monitora este repositório na branch `main`.

- Qualquer `git push` é detectado e aplicado automaticamente no cluster
- O overlay `fluxcd/apps/overlays/aws/` injeta `CLOUD_NAME=aws` via ConfigMap
- O Secret `db-credentials` contém a `DATABASE_URL` encriptada com SOPS + age

### Secrets necessários antes do primeiro sync

```bash
# Chave age para o FluxCD descriptografar os secrets
kubectl create secret generic sops-age -n flux-system \
  --from-file=identity.agekey=.sops/age.key

# Credenciais GHCR para pull da imagem
kubectl create secret docker-registry ghcr-credentials -n demo \
  --docker-server=ghcr.io \
  --docker-username=ncorazza12 \
  --docker-password="$GHCR_TOKEN"
```

---

## Ordem de execução

```
1. Criar cluster CockroachDB → copiar DATABASE_URL
2. Gerar chave age:  age-keygen -o .sops/age.key
3. Atualizar .sops.yaml com a nova chave pública
4. Re-encriptar:    sops -e -i fluxcd/apps/base/db-credentials.sops.yaml
5. Build + push da imagem Docker
6. cd terraform/aws && terraform init && terraform apply
7. kubectl create secret generic sops-age ...
8. kubectl create secret docker-registry ghcr-credentials ...
9. git push → FluxCD sincroniza automaticamente
10. Obter IP:       kubectl get svc -n demo
11. Configurar DNS Cloudflare apontando para o IP do LoadBalancer
12. Configurar Cloudflare Pages com VITE_API_URL
```

---

## Pré-requisitos

- Terraform ≥ 1.5
- AWS CLI configurado (`aws configure`)
- kubectl
- Docker
- age (`brew install age` / `apt install age`)
- SOPS (`brew install sops`)
- Conta [CockroachDB Serverless](https://cockroachlabs.cloud) (gratuita)
- Conta Cloudflare com domínio gerenciado

---

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| Frontend | React 18, Vite, TypeScript, Tailwind CSS, Radix UI, lucide-react, axios |
| Backend | Node.js 20, Express 4, pg |
| Banco | CockroachDB Serverless (compatível com Postgres) |
| Container | Docker, Node 20 alpine |
| Orquestração | Kubernetes — AWS EKS 1.31 |
| GitOps | FluxCD 2 (flux2 + flux2-sync via Helm) |
| Secrets | SOPS 3 + age |
| IaC | Terraform ≥ 1.5 (módulos terraform-aws-modules/vpc e /eks) |
| DNS / CDN | Cloudflare (DNS + Pages) |
| Registro de imagem | GitHub Container Registry (GHCR) |

---

*FIAP — Cloud Computing · Global Solutions 01 · 2026*
