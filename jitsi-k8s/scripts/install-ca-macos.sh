#!/bin/bash

# Install Certificate Authority on macOS System Keychain
# This script adds the local CA to macOS trusted certificates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/../certs"
CA_CERT="${CERTS_DIR}/ca-cert.pem"

# Check if CA certificate exists
if [ ! -f "${CA_CERT}" ]; then
    echo "Error: CA certificate not found at ${CA_CERT}"
    echo "Please run ./generate-ca.sh first."
    exit 1
fi

echo "=== Installing CA Certificate on macOS ==="
echo ""
echo "This script will:"
echo "1. Add the CA certificate to System Keychain"
echo "2. Set the certificate as trusted for SSL"
echo ""
echo "You will be prompted for your password (sudo access required)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Add certificate to System Keychain
echo "Adding CA certificate to System Keychain..."
sudo security add-trusted-cert -d -r trustRoot \
    -k /Library/Keychains/System.keychain \
    "${CA_CERT}"

echo ""
echo "✓ CA certificate installed successfully!"
echo ""
echo "The certificate has been added to your System Keychain and is trusted for:"
echo "  - SSL/TLS connections"
echo "  - Code signing"
echo "  - Email"
echo ""
echo "You can verify the installation by:"
echo "1. Opening 'Keychain Access' app"
echo "2. Selecting 'System' keychain"
echo "3. Looking for 'Jitsi Local CA'"
echo ""
echo "To remove the certificate later, run:"
echo "sudo security delete-certificate -c 'Jitsi Local CA' /Library/Keychains/System.keychain"
