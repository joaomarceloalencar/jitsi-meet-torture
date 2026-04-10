#!/bin/bash

# Generate Certificate Authority for Jitsi Meet
# This script creates a local CA for signing certificates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"

# Create certs directory if it doesn't exist
mkdir -p "${CERTS_DIR}"

echo "=== Generating Certificate Authority ==="

# Generate CA private key
if [ ! -f "${CERTS_DIR}/ca-key.pem" ]; then
    echo "Generating CA private key..."
    openssl genrsa -out "${CERTS_DIR}/ca-key.pem" 4096
    chmod 600 "${CERTS_DIR}/ca-key.pem"
else
    echo "CA private key already exists, skipping..."
fi

# Generate CA certificate
if [ ! -f "${CERTS_DIR}/ca-cert.pem" ]; then
    echo "Generating CA certificate..."
    openssl req -new -x509 -days 3650 -key "${CERTS_DIR}/ca-key.pem" \
        -out "${CERTS_DIR}/ca-cert.pem" \
        -subj "/C=US/ST=California/L=San Francisco/O=Jitsi Local CA/CN=Jitsi Local CA"
else
    echo "CA certificate already exists, skipping..."
fi

echo ""
echo "Certificate Authority created successfully!"
echo "CA certificate: ${CERTS_DIR}/ca-cert.pem"
echo "CA private key: ${CERTS_DIR}/ca-key.pem"
echo ""
echo "Next steps:"
echo "1. Run ./generate-certs.sh to create server certificates"
echo "2. Run ./install-ca-macos.sh to install the CA on macOS"
