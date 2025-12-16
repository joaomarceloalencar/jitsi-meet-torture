#!/bin/bash

# Redireciona toda a saída para o arquivo de log
exec > /home/ubuntu/jitsi-torture.log 2>&1

# Executa como usuário ubuntu se estiver rodando como root
if [ "$(id -u)" -eq 0 ]; then
    sudo -u ubuntu bash << 'EOF'
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
EOF
else
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
fi