#!/bin/bash

# Script para criar múltiplas instâncias EC2 com user data
# Uso: ./create_instances.sh <AMI_ID> <NUM_INSTANCES> [instance_type] [key_name] [security_group_id]

set -e

# Verifica se a AMI foi fornecida
if [ -z "$1" ]; then
    echo "Erro: AMI_ID é obrigatório"
    echo "Uso: $0 <AMI_ID> <NUM_INSTANCES> [instance_type] [key_name] [security_group_id]"
    exit 1
fi

# Verifica se o número de instâncias foi fornecido
if [ -z "$2" ]; then
    echo "Erro: NUM_INSTANCES é obrigatório"
    echo "Uso: $0 <AMI_ID> <NUM_INSTANCES> [instance_type] [key_name] [security_group_id]"
    exit 1
fi

# Verifica se o script user_data.sh existe
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/user_data.sh" ]; then
    echo "Erro: user_data.sh não encontrado em $SCRIPT_DIR"
    exit 1
fi

# Parâmetros
AMI_ID="$1"
NUM_INSTANCES="$2"
INSTANCE_TYPE="${3:-t3.medium}"
KEY_NAME="${4:-your-key-name}"
SECURITY_GROUP="${5:-}"

echo "Criando $NUM_INSTANCES instâncias EC2..."
echo "AMI: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Key Name: $KEY_NAME"

# Cria o user data
USER_DATA_TEMP=$(mktemp)
cat "$SCRIPT_DIR/user_data.sh" > "$USER_DATA_TEMP"

# Array para armazenar Instance IDs
INSTANCE_IDS=()

# Loop para criar múltiplas instâncias
for i in $(seq 1 $NUM_INSTANCES); do
    echo "Criando instância $i de $NUM_INSTANCES..."
    
    # Monta o comando de criação da instância
    CREATE_CMD="aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --user-data file://$USER_DATA_TEMP \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=jitsi-torture-$i}]'"
    
    # Adiciona security group se fornecido
    if [ -n "$SECURITY_GROUP" ]; then
        CREATE_CMD="$CREATE_CMD --security-group-ids $SECURITY_GROUP"
    fi
    
    # Adiciona configurações adicionais
    CREATE_CMD="$CREATE_CMD --output json"
    
    # Cria a instância
    INSTANCE_INFO=$(eval $CREATE_CMD)
    
    # Extrai o Instance ID
    INSTANCE_ID=$(echo $INSTANCE_INFO | jq -r '.Instances[0].InstanceId')
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "null" ]; then
        echo "Erro: Falha ao criar instância $i"
        continue
    fi
    
    INSTANCE_IDS+=("$INSTANCE_ID")
    echo "Instância $i criada: $INSTANCE_ID"
done

# Remove arquivo temporário
rm -f "$USER_DATA_TEMP"

if [ ${#INSTANCE_IDS[@]} -eq 0 ]; then
    echo "Erro: Nenhuma instância foi criada com sucesso"
    exit 1
fi

echo ""
echo "Aguardando todas as ${#INSTANCE_IDS[@]} instâncias ficarem em estado 'running'..."

# Aguarda todas as instâncias estarem em running
aws ec2 wait instance-running --instance-ids "${INSTANCE_IDS[@]}"

echo "Todas as instâncias estão em running!"

echo ""
echo "=========================================="
echo "Processo concluído com sucesso!"
echo "Total de instâncias criadas: ${#INSTANCE_IDS[@]}"
echo "=========================================="
echo ""
echo "Instâncias criadas:"
for INSTANCE_ID in "${INSTANCE_IDS[@]}"; do
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
        PUBLIC_IP="N/A"
    fi
    
    echo "  - $INSTANCE_ID: $PUBLIC_IP"
done

echo ""
echo "O user_data.sh será executado automaticamente nas instâncias."
echo ""
echo "Para verificar os logs de uma instância:"
echo "ssh -i ~/.ssh/$KEY_NAME.pem ubuntu@<IP> 'tail -f /home/ubuntu/setup.log'"
echo ""
echo "Para terminar todas as instâncias:"
echo "aws ec2 terminate-instances --instance-ids ${INSTANCE_IDS[*]}"
