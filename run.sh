#!/bin/bash
exec > /home/ubuntu/jitsi-torture.log.log 2>&1
INSTANCE=$1

# Para os contêineres
cd /home/ubuntu/jitsi-meet-torture/doc/grid
docker compose -f docker-compose.yml down
docker compose -f docker-compose.yml up -d

# Espera o serviço estar pronto
STATUS=$(curl -s http://localhost:4444/wd/hub/status | jq -r '.value.ready')
until [[ "$STATUS" =~ ^true ]]; do
    sleep 5
    STATUS=$(curl -s http://localhost:4444/wd/hub/status | jq -r '.value.ready')
done

# Executa o teste
cd /home/ubuntu/jitsi-meet-torture/
./scripts/malleus.sh \
	--conferences=1 \
	--participants=2 \
	--senders=1 \
	--audio-senders=1 \
	--duration=120 \
	--hub-url=http://localhost:4444/wd/hub \
	--allow-insecure-certs=true \
	--use-load-test \
	--instance-url=https://${INSTANCE}/