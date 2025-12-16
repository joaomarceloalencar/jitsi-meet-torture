#!/bin/bash

cd /home/ubuntu/jitsi-meet-torture/doc/grid
docker compose -f docker-compose-v3-dynamic-grid.yml up -d

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
	--instance-url=https://jitsi.joao.marcelo.nom.br/
