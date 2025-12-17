#!/bin/bash

# User data apenas prepara a instância - os testes serão executados via SSH

# Redireciona toda a saída para o arquivo de log
exec > /home/ubuntu/setup.log 2>&1

echo "$(date): Inicializando instância..."
echo "$(date): Instância pronta para receber comandos via SSH"

# Remove logs anteriores
rm -f /home/ubuntu/jitsi-torture.log

# Recupera os scripts necessários
git clone https://github.com/joaomarceloalencar/jitsi-meet-torture.git /home/ubuntu/scripts`
