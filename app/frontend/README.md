# GS01 Frontend

React 18 + Vite + TypeScript frontend.

## Environment

Create `app/frontend/.env.local` for local development:

```bash
VITE_API_URL=http://localhost:3000
```

Em produção, set `VITE_API_URL` para o IP do LoadBalancer do EKS.

## Scripts

```bash
npm install
npm run dev
npm run build
```