#!/usr/bin/env bash
# Reference script — prints the CLI commands for manual setup.
# Most users follow the Console walkthrough in README.md.
set -euo pipefail
REGION="${1:-us-east-1}"
REPO="topnet-vless"
CLUSTER="topnet-cluster"
ROLE="ecsTaskRole-${REPO}"

echo "==> 1) ECR repository"
aws ecr describe-repositories --repository-names "$REPO" 2>/dev/null \
  || aws ecr create-repository --repository-name "$REPO" --region "$REGION"

echo "==> 2) ECS task execution role"
aws iam create-role --role-name "$ROLE" \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  --region "$REGION" 2>/dev/null || true
aws iam attach-role-policy --role-name "$ROLE" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
  --region "$REGION"

echo "==> 3) ECS cluster"
aws ecs describe-clusters --clusters "$CLUSTER" --region "$REGION" 2>/dev/null \
  || aws ecs create-cluster --cluster-name "$CLUSTER" --region "$REGION"

cat <<EOF

Next (Console):
  CodePipeline > Create > Express > connect GitHub > pick repo/main
  Dockerfile at /, container port 8080
  Create new ALB: HTTPS:443 with ACM cert for hezpaty.hezz.dpdns.org
    + HTTP:8080, both -> new target group port 8080, health path /healthz
  Then in dpdns.org point hezpaty.hezz.dpdns.org A-record at the ALB DNS
  Push app.js (DOMAIN already set to hezpaty.hezz.dpdns.org)
EOF
