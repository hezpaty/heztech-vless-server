# VLESS WS-TLS Proxy — AWS CodePipeline Express + DPDNS Domain

Auto-builds & redeploys a VLESS WS-TLS proxy on every `git push`.
Serves `wss://hezpaty.hezz.dpdns.org/topnet` with a valid Let's Encrypt cert.

## Repo layout
- `app.js` — your VLESS server (unmodified except `DOMAIN`)
- `Dockerfile` — packages app + nginx + certbot
- `nginx.conf` — TLS termination, WS upgrade, /healthz
- `entrypoint.sh` — boots node + nginx, runs certbot (initial + 6h renewals)
- `package.json` — pins `ws` (the dynamic `ensureModule` also works)
- `.aws/codebuild/buildspec.yml` — no-op buildspec (Express handles it)
- `deploy.sh` — optional CLI reference

## Deploy
1. Push to GitHub `main`.
2. AWS Console → CodePipeline → Create → **Express** → connect GitHub →
   repo `main` branch.
3. Dockerfile at root, container port **8080**.
4. ECS: new Fargate cluster, new service, new task def (0.5 vCPU/1 GB),
   task role `ecsTaskRole-topnet-vless`.
5. Load balancer: **create new ALB**, HTTPS:443 with a **new ACM cert**
   for `hezpaty.hezz.dpdns.org` (DNS validation), HTTP:8080 listener,
   both → new target group on port 8080, health path `/healthz`.
6. Validate the ACM cert in ACM console (add the CNAME to dpdns.org).
7. In dpdns.org, point `hezpaty.hezz.dpdns.org` A-record at the ALB DNS.
8. Push any change to `app.js` → pipeline auto-rebuilds + redeploys.

## Client endpoints
- Health: `https://hezpaty.hezz.dpdns.org/healthz`
- VLESS URL: `https://hezpaty.hezz.dpdns.org/<UUID>`
- Full client config: `https://hezpaty.hezz.dpdns.org/client-config`

## Cert
ACM cert (requested during ALB creation) is what clients actually see —
the ALB terminates TLS. The in-container certbot is a secondary fallback
in case the ALB cert expires; it renews every 6 h.

## Cost (low traffic)
Fargate ~$8/mo · ALB ~$1–3/mo · ECR/ACM/CloudWatch ~$0–1 · Total ~$10/mo
