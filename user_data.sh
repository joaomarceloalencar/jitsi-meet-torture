#!/bin/bash

# User data apenas prepara a instância - os testes serão executados via SSH

echo "$(date): Inicializando instância..."
echo "$(date): Instância pronta para receber comandos via SSH"

# Remove logs anteriores
rm -f /home/ubuntu/jitsi-torture.log

# Recupera os scripts necessários
git clone https://github.com/joaomarceloalencar/jitsi-meet-torture.git /home/ubuntu/scripts

# Torna os scripts executáveis
chmod +x /home/ubuntu/scripts/run.sh