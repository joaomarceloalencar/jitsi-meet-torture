#!/bin/bash

# Jitsi Meet Kubernetes Setup Script
# This script automates the complete setup process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
K8S_DIR="${PROJECT_DIR}/k8s"
CERTS_DIR="${PROJECT_DIR}/certs"
DOMAIN="jitsi.macbookpro"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Jitsi Meet Kubernetes Setup${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if Kubernetes is running
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster. Please ensure Kubernetes is running.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found and Kubernetes cluster is accessible${NC}"

# Check openssl
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl not found. Please install openssl first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ openssl found${NC}"
echo ""

# Generate certificates if they don't exist
if [ ! -f "${CERTS_DIR}/tls.crt" ] || [ ! -f "${CERTS_DIR}/tls.key" ]; then
    echo -e "${YELLOW}Generating certificates...${NC}"
    
    # Generate CA
    if [ ! -f "${CERTS_DIR}/ca-cert.pem" ]; then
        "${SCRIPT_DIR}/generate-ca.sh"
    fi
    
    # Generate server certificates
    "${SCRIPT_DIR}/generate-certs.sh"
    
    echo -e "${GREEN}✓ Certificates generated${NC}"
else
    echo -e "${GREEN}✓ Certificates already exist${NC}"
fi
echo ""

# Generate secrets
echo -e "${YELLOW}Generating secrets and passwords...${NC}"

# Generate random passwords
JICOFO_AUTH_PASSWORD=$(openssl rand -hex 32)
JVB_AUTH_PASSWORD=$(openssl rand -hex 32)
JIGASI_XMPP_PASSWORD=$(openssl rand -hex 32)
JIBRI_RECORDER_PASSWORD=$(openssl rand -hex 32)
JIBRI_XMPP_PASSWORD=$(openssl rand -hex 32)

# Generate JWT secret and key
JWT_APP_SECRET=$(openssl rand -hex 32)
JWT_APP_KEY=$(openssl rand -base64 32)

echo -e "${GREEN}✓ Secrets generated${NC}"
echo ""

# Create secrets manifest
echo -e "${YELLOW}Creating secrets manifest...${NC}"

# Base64 encode certificates
TLS_CRT_BASE64=$(base64 < "${CERTS_DIR}/tls.crt" | tr -d '\n')
TLS_KEY_BASE64=$(base64 < "${CERTS_DIR}/tls.key" | tr -d '\n')

# Base64 encode passwords and JWT
JICOFO_AUTH_PASSWORD_BASE64=$(echo -n "${JICOFO_AUTH_PASSWORD}" | base64 | tr -d '\n')
JVB_AUTH_PASSWORD_BASE64=$(echo -n "${JVB_AUTH_PASSWORD}" | base64 | tr -d '\n')
JIGASI_XMPP_PASSWORD_BASE64=$(echo -n "${JIGASI_XMPP_PASSWORD}" | base64 | tr -d '\n')
JIBRI_RECORDER_PASSWORD_BASE64=$(echo -n "${JIBRI_RECORDER_PASSWORD}" | base64 | tr -d '\n')
JIBRI_XMPP_PASSWORD_BASE64=$(echo -n "${JIBRI_XMPP_PASSWORD}" | base64 | tr -d '\n')
JWT_APP_SECRET_BASE64=$(echo -n "${JWT_APP_SECRET}" | base64 | tr -d '\n')
JWT_APP_KEY_BASE64=$(echo -n "${JWT_APP_KEY}" | base64 | tr -d '\n')

# Replace placeholders in template
sed "s|__TLS_CRT_BASE64__|${TLS_CRT_BASE64}|g; \
     s|__TLS_KEY_BASE64__|${TLS_KEY_BASE64}|g; \
     s|__JWT_APP_SECRET_BASE64__|${JWT_APP_SECRET_BASE64}|g; \
     s|__JWT_APP_KEY_BASE64__|${JWT_APP_KEY_BASE64}|g; \
     s|__JICOFO_AUTH_PASSWORD_BASE64__|${JICOFO_AUTH_PASSWORD_BASE64}|g; \
     s|__JVB_AUTH_PASSWORD_BASE64__|${JVB_AUTH_PASSWORD_BASE64}|g; \
     s|__JIGASI_XMPP_PASSWORD_BASE64__|${JIGASI_XMPP_PASSWORD_BASE64}|g; \
     s|__JIBRI_RECORDER_PASSWORD_BASE64__|${JIBRI_RECORDER_PASSWORD_BASE64}|g; \
     s|__JIBRI_XMPP_PASSWORD_BASE64__|${JIBRI_XMPP_PASSWORD_BASE64}|g" \
     "${K8S_DIR}/03-secrets.yaml.template" > "${K8S_DIR}/03-secrets.yaml"

# Save JWT secret to file for token generation
mkdir -p "${PROJECT_DIR}/.secrets"
echo "${JWT_APP_SECRET}" > "${PROJECT_DIR}/.secrets/jwt_app_secret"
echo "${JWT_APP_KEY}" > "${PROJECT_DIR}/.secrets/jwt_app_key"
chmod 600 "${PROJECT_DIR}/.secrets/"*

echo -e "${GREEN}✓ Secrets manifest created${NC}"
echo ""

# Check /etc/hosts
echo -e "${YELLOW}Checking /etc/hosts configuration...${NC}"
if ! grep -q "${DOMAIN}" /etc/hosts; then
    echo -e "${YELLOW}Warning: ${DOMAIN} not found in /etc/hosts${NC}"
    echo -e "${YELLOW}Please add the following line to /etc/hosts (requires sudo):${NC}"
    echo -e "${BLUE}127.0.0.1 ${DOMAIN}${NC}"
    echo ""
    read -p "Would you like to add it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "127.0.0.1 ${DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
        echo -e "${GREEN}✓ Added ${DOMAIN} to /etc/hosts${NC}"
    fi
else
    echo -e "${GREEN}✓ ${DOMAIN} found in /etc/hosts${NC}"
fi
echo ""

# Apply Kubernetes manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"
echo ""

# Apply nginx-ingress-controller
# echo -e "${BLUE}1. Deploying nginx-ingress-controller...${NC}"
# kubectl apply -f "${K8S_DIR}/01-nginx-ingress-controller.yaml"
# echo -e "${GREEN}✓ nginx-ingress-controller deployed${NC}"
# echo ""

# Wait for nginx-ingress-controller to be ready
echo -e "${YELLOW}Waiting for nginx-ingress-controller to be ready...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=ingress-nginx \
  --timeout=300s
echo -e "${GREEN}✓ nginx-ingress-controller is ready${NC}"
echo ""

# Apply namespace
echo -e "${BLUE}2. Creating jitsi namespace...${NC}"
kubectl apply -f "${K8S_DIR}/00-namespace.yaml"
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Apply secrets
echo -e "${BLUE}3. Creating secrets...${NC}"
kubectl apply -f "${K8S_DIR}/03-secrets.yaml"
echo -e "${GREEN}✓ Secrets created${NC}"
echo ""

# Apply ConfigMaps
echo -e "${BLUE}4. Creating ConfigMaps...${NC}"
kubectl apply -f "${K8S_DIR}/02-configmaps.yaml"
echo -e "${GREEN}✓ ConfigMaps created${NC}"
echo ""

# Apply Services
echo -e "${BLUE}5. Creating Services...${NC}"
kubectl apply -f "${K8S_DIR}/05-services.yaml"
echo -e "${GREEN}✓ Services created${NC}"
echo ""

# Apply Deployments
echo -e "${BLUE}6. Creating Deployments...${NC}"
kubectl apply -f "${K8S_DIR}/04-deployments.yaml"
echo -e "${GREEN}✓ Deployments created${NC}"
echo ""

# Apply HPA
echo -e "${BLUE}7. Creating HorizontalPodAutoscaler...${NC}"
kubectl apply -f "${K8S_DIR}/06-hpa.yaml"
echo -e "${GREEN}✓ HPA created${NC}"
echo ""

# Apply Ingress
echo -e "${BLUE}8. Creating Ingress...${NC}"
kubectl apply -f "${K8S_DIR}/07-ingress.yaml"
echo -e "${GREEN}✓ Ingress created${NC}"
echo ""

echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
echo "This may take a few minutes..."
echo ""

kubectl wait --namespace jitsi \
  --for=condition=ready pod \
  --selector=app=jitsi-meet \
  --timeout=300s || true

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo -e "1. Install CA certificate on macOS (if not already done):"
echo -e "   ${YELLOW}./scripts/install-ca-macos.sh${NC}"
echo ""
echo -e "2. Access Jitsi Meet at:"
echo -e "   ${GREEN}https://${DOMAIN}${NC}"
echo ""
echo -e "3. Generate JWT token for authentication:"
echo -e "   ${YELLOW}./scripts/generate-jwt-token.sh <username> <moderator|user>${NC}"
echo ""
echo -e "4. Check deployment status:"
echo -e "   ${YELLOW}kubectl get all -n jitsi${NC}"
echo ""
echo -e "5. View logs:"
echo -e "   ${YELLOW}kubectl logs -n jitsi -l component=web${NC}"
echo -e "   ${YELLOW}kubectl logs -n jitsi -l component=prosody${NC}"
echo -e "   ${YELLOW}kubectl logs -n jitsi -l component=jicofo${NC}"
echo -e "   ${YELLOW}kubectl logs -n jitsi -l component=jvb${NC}"
echo ""
echo -e "6. Scale JVB manually:"
echo -e "   ${YELLOW}kubectl scale deployment jvb -n jitsi --replicas=<number>${NC}"
echo ""
echo -e "${BLUE}JWT credentials saved to:${NC}"
echo -e "   ${PROJECT_DIR}/.secrets/jwt_app_secret"
echo -e "   ${PROJECT_DIR}/.secrets/jwt_app_key"
echo ""
