#!/bin/sh
set -e

DOMAIN="${DOMAIN:-hezpaty.hezz.dpdns.org}"
CERT_DIR="/etc/letsencrypt/live/${DOMAIN}"
WEBROOT="/var/www/certbot"
EMAIL="admin@${DOMAIN}"

mkdir -p "$CERT_DIR" "$WEBROOT"

# certbot deploy hook: reload nginx after renew
cat > /usr/local/bin/reload-nginx <<'EOF'
#!/bin/sh
nginx -s reload || true
EOF
chmod +x /usr/local/bin/reload-nginx

# 1) Initial cert issue. If the domain isn't yet pointing at the ALB,
#    this will fail once — the loop below retries every 6 hours.
echo "[certbot] requesting initial cert for ${DOMAIN}"
certbot certonly --webroot -w "$WEBROOT" \
    --agree-tos -m "$EMAIL" --no-eff-email \
    -d "$DOMAIN" \
    --deploy-hook /usr/local/bin/reload-nginx || true

# 2) Auto-renew every 6 hours (certs last 90 days; LE recommends 30-day interval)
(
    while :; do
        sleep 21600
        certbot renew --quiet --webroot -w "$WEBROOT" \
            --deploy-hook /usr/local/bin/reload-nginx || true
    done
) &

# 3) Start the Node VLESS app in the background on the internal port
echo "[app] starting node app.js on 127.0.0.1:${APP_PORT:-8081}"
PORT="${APP_PORT:-8081}" node /app/app.js &
NODE_PID=$!

# Keep the node process alive; if it crashes, exit the container so ECS restarts it
trap "kill $NODE_PID 2>/dev/null" TERM INT
wait $NODE_PID &
WAIT_PID=$!

# 4) Start nginx in the foreground
echo "[nginx] starting on ${NGINX_PORT:-8080}"
nginx -g "daemon off;" &
NGINX_PID=$!

wait $WAIT_PID $NGINX_PID
