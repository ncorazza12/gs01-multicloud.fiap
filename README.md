# GS01 Multicloud · FIAP

**Global Solutions 01 — Cloud Computing 2026**  
Aluno: **rm562265**

Aplicação fullstack multicloud ativo-ativo rodando em **AWS EKS** e **Azure AKS**, com frontend hospedado no **Cloudflare Pages**, banco de dados **CockroachDB Serverless** compartilhado entre as duas nuvens, infraestrutura provisionada via **Terraform** e deploy contínuo pelo **FluxCD** (GitOps).

---

## Arquitetura

```
Usuário
  │
  ▼
Cloudflare Pages  (React 18 + Vite + TypeScript)
  │  fetch /api/subjects
  ▼
DNS Cloudflare "api-rm562265.<zona>"  (round-robin)
  ├──▶ AWS EKS LoadBalancer  →  Pod Node.js/Express  (CLOUD_NAME=aws)
  └──▶ Azure AKS LoadBalancer →  Pod Node.js/Express  (CLOUD_NAME=azure)
                   │                        │
                   └──────────┬─────────────┘
                              ▼
                   CockroachDB Serverless
                   (mesma DATABASE_URL nos dois clusters)
```

Cada requisição da API retorna o campo `cloud` indicando qual cluster respondeu (`aws` ou `azure`). O frontend exibe esse valor em tempo real no badge **"Servido por AWS"** / **"Servido por Azure"**.

---

## Estrutura do Repositório

```
gs01-multicloud.fiap/
├── app/
│   ├── backend/                  # Node.js + Express + pg
│   │   ├── server.js             # Rotas, startup, graceful shutdown
│   │   ├── db.js                 # Pool pg, ensureSchema, seed
│   │   ├── Dockerfile            # Node 20 alpine
│   │   └── package.json
│   └── frontend/                 # React 18 + Vite + TypeScript + Tailwind
│       └── src/
│           ├── App.tsx
│           ├── components/
│           │   ├── AddSubjectForm.tsx   # Dialog Radix UI para nova matéria
│           │   ├── CloudBadge.tsx       # Badge que mostra qual cloud respondeu
│           │   └── SubjectTable.tsx     # Tabela com checkbox e botão deletar
│           ├── hooks/
│           │   └── useSubjects.ts       # Estado + chamadas à API (axios)
│           └── lib/
│               └── api.ts              # Instância axios com VITE_API_URL
├── fluxcd/
│   └── apps/
│       ├── base/
│       │   ├── namespace.yaml          # Namespace "demo"
│       │   ├── deployment.yaml         # Deployment gs01-api (imagem GHCR)
│       │   ├── service.yaml            # Service LoadBalancer porta 80→3000
│       │   ├── db-credentials.sops.yaml # Secret DATABASE_URL encriptado (SOPS+age)
│       │   └── kustomization.yaml
│       └── overlays/
│           └── aws/
│               └── kustomization.yaml  # ConfigMap CLOUD_NAME=aws
└── terraform/
    └── aws/
        ├── 00-provider.tf        # Provider AWS + Helm, locals (projeto, região)
        ├── 01-vpc.tf             # VPC com subnets públicas e privadas
        ├── 02-eks.tf             # Cluster EKS 1.31 + node group t3.medium
        └── 03-fluxcd.tf         # Helm release flux2 + flux2-sync apontando para este repo
```

---

## Backend (`app/backend`)

API REST Node.js + Express conectada ao CockroachDB via `pg` (driver Postgres).

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
| `DATABASE_URL` | ✅ | — | Connection string CockroachDB/Postgres |
| `CLOUD_NAME` | — | `unknown` | `aws` ou `azure` — retornado em todas as respostas |
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

### O que faz

- Lista as matérias cadastradas no banco com atualização em tempo real
- Exibe badge **"Servido por AWS"** ou **"Servido por Azure"** conforme o cluster que respondeu
- Permite adicionar novas matérias via dialog (Radix UI)
- Permite marcar matérias como concluídas (checkbox com risco visual)
- Permite deletar matérias (botão com ícone `Trash2` do lucide-react)
- Toast de confirmação após criar ou deletar

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

### Build

```bash
npm run build  # output: dist/
```

---

## Infraestrutura (`terraform/aws`)

Terraform provisiona toda a infraestrutura AWS:

| Arquivo | O que cria |
|---------|-----------|
| `00-provider.tf` | Provider AWS (`~> 6.0`), Helm, locals (`project=rm562265`, `region=us-east-2`) |
| `01-vpc.tf` | VPC `10.0.0.0/16`, 2 subnets privadas, 2 públicas, NAT Gateway |
| `02-eks.tf` | Cluster EKS 1.31 (`eks-rm562265-dev`), node group `t3.medium` (1–2 nós), addons coredns/kube-proxy/vpc-cni |
| `03-fluxcd.tf` | Helm release `flux2` + `flux2-sync` apontando para este repositório, com decryptação SOPS/age |

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

O FluxCD é instalado via Terraform e monitora este repositório continuamente.

- `fluxcd/apps/overlays/aws/` → aplicado no cluster EKS com `CLOUD_NAME=aws`
- O Deployment puxa a imagem `ghcr.io/ncorazza12/gs01-multicloud.fiap/gs01-api:v1` do GHCR
- O Secret `db-credentials` contém a `DATABASE_URL` encriptada com SOPS + age
- Qualquer `git push` na branch `main` é detectado e aplicado automaticamente no cluster

### Secrets necessários antes do primeiro sync

```bash
# 1. Secret da chave age para o FluxCD descriptografar
kubectl create secret generic sops-age -n flux-system \
  --from-file=identity.agekey=.sops/age.key

# 2. Credenciais GHCR para pull da imagem
kubectl create secret docker-registry ghcr-credentials -n demo \
  --docker-server=ghcr.io \
  --docker-username=ncorazza12 \
  --docker-password="$GHCR_TOKEN"
```

---

## Pré-requisitos

- Terraform ≥ 1.5
- AWS CLI + credenciais configuradas (`aws configure`)
- kubectl
- Docker
- age (`brew install age` / `apt install age`)
- SOPS (`brew install sops` / binário no GitHub)
- Conta CockroachDB Serverless (gratuita em [cockroachlabs.cloud](https://cockroachlabs.cloud))
- Conta Cloudflare com domínio gerenciado (para Pages + DNS)

---

## Ordem de execução completa

```
1. Criar cluster CockroachDB → copiar DATABASE_URL
2. Gerar chave age → age-keygen -o .sops/age.key
3. Atualizar .sops.yaml com a nova chave pública
4. Re-encriptar: sops -e -i fluxcd/apps/base/db-credentials.sops.yaml
5. Build + push da imagem Docker → ghcr.io/ncorazza12/...
6. cd terraform/aws && terraform init && terraform apply
7. kubectl create secret generic sops-age ...
8. kubectl create secret docker-registry ghcr-credentials ...
9. git push → FluxCD sincroniza automaticamente
10. Obter IPs: kubectl get svc -n demo
11. Configurar DNS Cloudflare (round-robin apontando para os IPs)
12. Configurar Cloudflare Pages com VITE_API_URL
```

---

## Tecnologias

| Camada | Tecnologia |
|--------|-----------|
| Frontend | React 18, Vite, TypeScript, Tailwind CSS, Radix UI, lucide-react, axios |
| Backend | Node.js 20, Express 4, pg (driver Postgres) |
| Banco | CockroachDB Serverless (compatível com Postgres) |
| Container | Docker, Node 20 alpine |
| Orquestração | Kubernetes (EKS 1.31 / AKS 1.31) |
| GitOps | FluxCD 2 (flux2 + flux2-sync via Helm) |
| Secrets | SOPS 3 + age (encriptação em repouso no Git) |
| IaC | Terraform ≥ 1.5 (módulos terraform-aws-modules/vpc e /eks) |
| DNS / CDN | Cloudflare (DNS round-robin + Pages) |
| Registro | GitHub Container Registry (GHCR) |

---

*FIAP — Cloud Computing · Global Solutions 01 · 2026*
