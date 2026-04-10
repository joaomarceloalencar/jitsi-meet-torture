#!/bin/bash

# Cleanup script for Jitsi Meet Kubernetes deployment
# This script removes all Kubernetes resources created by the setup script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
K8S_DIR="${PROJECT_DIR}/k8s"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}======================================${NC}"
echo -e "${RED}  Jitsi Meet Kubernetes Cleanup${NC}"
echo -e "${RED}======================================${NC}"
echo ""
echo -e "${YELLOW}This will delete all Jitsi Meet resources from Kubernetes.${NC}"
echo -e "${YELLOW}This action cannot be undone.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no) " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting Kubernetes resources...${NC}"
echo ""

# Delete in reverse order
echo -e "${BLUE}1. Deleting Ingress...${NC}"
kubectl delete -f "${K8S_DIR}/07-ingress.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ Ingress deleted${NC}"
echo ""

echo -e "${BLUE}2. Deleting HPA...${NC}"
kubectl delete -f "${K8S_DIR}/06-hpa.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ HPA deleted${NC}"
echo ""

echo -e "${BLUE}3. Deleting Deployments...${NC}"
kubectl delete -f "${K8S_DIR}/04-deployments.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ Deployments deleted${NC}"
echo ""

echo -e "${BLUE}4. Deleting Services...${NC}"
kubectl delete -f "${K8S_DIR}/05-services.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ Services deleted${NC}"
echo ""

echo -e "${BLUE}5. Deleting ConfigMaps...${NC}"
kubectl delete -f "${K8S_DIR}/02-configmaps.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ ConfigMaps deleted${NC}"
echo ""

echo -e "${BLUE}6. Deleting Secrets...${NC}"
kubectl delete -f "${K8S_DIR}/03-secrets.yaml" --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Secrets deleted${NC}"
echo ""

echo -e "${BLUE}7. Deleting Namespace...${NC}"
kubectl delete -f "${K8S_DIR}/00-namespace.yaml" --ignore-not-found=true
echo -e "${GREEN}✓ Namespace deleted${NC}"
echo ""

echo -e "${YELLOW}Do you want to delete nginx-ingress-controller as well? (y/n)${NC}"
read -p "" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}8. Deleting nginx-ingress-controller...${NC}"
    kubectl delete -f "${K8S_DIR}/01-nginx-ingress-controller.yaml" --ignore-not-found=true
    echo -e "${GREEN}✓ nginx-ingress-controller deleted${NC}"
else
    echo -e "${YELLOW}Skipping nginx-ingress-controller deletion${NC}"
fi
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}Note:${NC}"
echo -e "- Certificates in ${PROJECT_DIR}/certs/ are preserved"
echo -e "- JWT secrets in ${PROJECT_DIR}/.secrets/ are preserved"
echo -e "- Generated secrets manifest ${K8S_DIR}/03-secrets.yaml is preserved"
echo ""
echo -e "${YELLOW}To completely remove all files:${NC}"
echo -e "  rm -rf ${PROJECT_DIR}/certs"
echo -e "  rm -rf ${PROJECT_DIR}/.secrets"
echo -e "  rm -f ${K8S_DIR}/03-secrets.yaml"
echo ""
echo -e "${YELLOW}To remove CA from macOS keychain:${NC}"
echo -e "  sudo security delete-certificate -c 'Jitsi Local CA' /Library/Keychains/System.keychain"
echo ""
echo -e "${YELLOW}To remove /etc/hosts entry:${NC}"
echo -e "  sudo sed -i '' '/jitsi.macbookpro/d' /etc/hosts"
echo ""
