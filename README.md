# GS01 Multicloud FIAP

Projeto GS01 com uma aplicacao React hospedada no Cloudflare Pages, uma API Node.js/Express rodando em AWS EKS e Azure AKS, DNS round-robin no Cloudflare e CockroachDB Serverless como banco externo compartilhado.

## Arquitetura

```text
Usuario
  |
  v
Cloudflare Pages (frontend React)
  |
  | fetch /api/subjects
  v
DNS Cloudflare api-rm562192.<zona> (round-robin A)
  |-- AWS EKS LoadBalancer -> Pod Node.js + Express (CLOUD_NAME=aws)
  |-- Azure AKS LoadBalancer -> Pod Node.js + Express (CLOUD_NAME=azure)
                                      |
                                      v
                         CockroachDB Serverless (Postgres)
```

## Pre-requisitos

- Terraform >= 1.5
- AWS CLI autenticado
- Azure CLI autenticado
- kubectl
- Docker
- Conta Cloudflare com zona DNS ativa
- Conta CockroachDB Serverless
- Node.js 20 para build local do frontend/backend

## Estrutura

```text
app/backend/       API Express, schema, seed e Dockerfile
app/frontend/      React 18 + Vite + TypeScript + Tailwind
aws/               VPC, EKS e FluxCD via Helm
azure/             VNet, AKS e FluxCD via Helm
fluxcd/            Kustomize base e overlays aws/azure
cloudflare/        DNS round-robin e Cloudflare Pages
```

## Ordem de execucao

1. Crie um CockroachDB Serverless e copie a `DATABASE_URL`.

2. Provisione AWS EKS:

```bash
cd aws
terraform init
terraform apply
```

3. Provisione Azure AKS:

```bash
cd azure
terraform init
terraform apply
```

4. Configure o kubectl para cada cluster:

```bash
aws eks update-kubeconfig --region eu-west-2 --name eks-rm562192-dev --alias aws-dev
az aks get-credentials --resource-group rg-rm562192-dev --name aks-rm562192-dev --context azure-dev
```

5. Crie os secrets operacionais nos dois clusters:

```bash
kubectl create secret generic sops-age -n flux-system --context aws-dev \
  --from-file=identity.agekey=.sops/age.key

kubectl create secret generic sops-age -n flux-system --context azure-dev \
  --from-file=identity.agekey=.sops/age.key

kubectl create secret docker-registry ghcr-credentials -n demo --context aws-dev \
  --docker-server=ghcr.io \
  --docker-username=luizbrito7 \
  --docker-password="$GHCR_TOKEN"

kubectl create secret docker-registry ghcr-credentials -n demo --context azure-dev \
  --docker-server=ghcr.io \
  --docker-username=luizbrito7 \
  --docker-password="$GHCR_TOKEN"
```

O secret `db-credentials` fica criptografado no Git com SOPS + age em `fluxcd/apps/base/db-credentials.sops.yaml` e e sincronizado pelo FluxCD.

6. Gere e publique a imagem da API:

```bash
cd app/backend
docker login ghcr.io -u luizbrito7
docker build -t ghcr.io/luizbrito7/gs01-multicloud.fiap/gs01-api:v1 .
docker push ghcr.io/luizbrito7/gs01-multicloud.fiap/gs01-api:v1
```

7. Confirme que `fluxcd/apps/base/deployment.yaml` aponta para `ghcr.io/luizbrito7/gs01-multicloud.fiap/gs01-api:v1`.

8. Envie as mudancas para a branch `main`. O FluxCD sincroniza os overlays:

```bash
git push origin main
```

9. Obtenha os IPs externos dos LoadBalancers:

```bash
kubectl get svc gs01-api -n demo --context aws-dev
kubectl get svc gs01-api -n demo --context azure-dev
```

10. Configure Cloudflare:

```bash
cd cloudflare
cp terraform.tfvars.example terraform.tfvars
```

Preencha `terraform.tfvars` com token, zone/account IDs, zona DNS e IPs dos LoadBalancers. Depois aplique:

```bash
terraform init
terraform apply
```

11. No Cloudflare Pages, use:

```text
Build command: npm run build
Output directory: dist
Root directory: app/frontend
Node version: 20
```

O Terraform define `VITE_API_URL=https://api-rm562192.<zona>`.

## Teste end-to-end

Verifique a API:

```bash
curl https://api-rm562192.<zona>/health
curl https://api-rm562192.<zona>/api/subjects
curl -X POST https://api-rm562192.<zona>/api/subjects \
  -H 'content-type: application/json' \
  -d '{"name":"Teste GS01"}'
```

Verifique os clusters:

```bash
kubectl get pods -n demo --context aws-dev
kubectl get pods -n demo --context azure-dev
kubectl logs deploy/gs01-api -n demo --context aws-dev
kubectl logs deploy/gs01-api -n demo --context azure-dev
```

Abra a URL do Cloudflare Pages e confirme:

- A tabela carrega as materias do CockroachDB.
- O badge alterna entre `Servido por AWS` e `Servido por Azure` conforme o DNS distribui requests.
- Criar, concluir e excluir materias reflete no banco compartilhado.
