#!/bin/bash

# Generate TLS certificates for Jitsi Meet signed by local CA
# This script creates server certificates for jitsi.macbookpro

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"
DOMAIN="jitsi.macbookpro"

# Check if CA exists
if [ ! -f "${CERTS_DIR}/ca-cert.pem" ] || [ ! -f "${CERTS_DIR}/ca-key.pem" ]; then
    echo "Error: CA not found. Please run ./generate-ca.sh first."
    exit 1
fi

echo "=== Generating TLS Certificates for ${DOMAIN} ==="

# Generate server private key
if [ ! -f "${CERTS_DIR}/tls.key" ]; then
    echo "Generating server private key..."
    openssl genrsa -out "${CERTS_DIR}/tls.key" 2048
    chmod 600 "${CERTS_DIR}/tls.key"
else
    echo "Server private key already exists, skipping..."
fi

# Generate Certificate Signing Request (CSR)
echo "Generating Certificate Signing Request..."
openssl req -new -key "${CERTS_DIR}/tls.key" \
    -out "${CERTS_DIR}/tls.csr" \
    -subj "/C=US/ST=California/L=San Francisco/O=Jitsi Local/CN=${DOMAIN}"

# Create certificate extensions file
cat > "${CERTS_DIR}/cert-extensions.cnf" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

# Sign the certificate with CA
echo "Signing certificate with CA..."
openssl x509 -req -in "${CERTS_DIR}/tls.csr" \
    -CA "${CERTS_DIR}/ca-cert.pem" \
    -CAkey "${CERTS_DIR}/ca-key.pem" \
    -CAcreateserial \
    -out "${CERTS_DIR}/tls.crt" \
    -days 825 \
    -sha256 \
    -extfile "${CERTS_DIR}/cert-extensions.cnf"

# Clean up CSR and extensions file
rm -f "${CERTS_DIR}/tls.csr" "${CERTS_DIR}/cert-extensions.cnf"

echo ""
echo "TLS certificates created successfully!"
echo "Certificate: ${CERTS_DIR}/tls.crt"
echo "Private key: ${CERTS_DIR}/tls.key"
echo ""
echo "Next steps:"
echo "1. Run ./install-ca-macos.sh to install the CA on macOS"
echo "2. Add '127.0.0.1 ${DOMAIN}' to /etc/hosts"
echo "3. Apply Kubernetes manifests"
