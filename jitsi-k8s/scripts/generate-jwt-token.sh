#!/bin/bash

# Generate JWT token for Jitsi Meet authentication
# Usage: ./generate-jwt-token.sh <username> <role>
# Role can be: moderator or user

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
SECRETS_DIR="${PROJECT_DIR}/.secrets"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3."
    exit 1
fi

# Check if PyJWT is installed
if ! python3 -c "import jwt" 2>/dev/null; then
    echo "Installing PyJWT..."
    pip3 install --break-system-packages PyJWT 2>/dev/null || pip3 install PyJWT
fi

# Parse arguments
USERNAME="${1:-testuser}"
ROLE="${2:-moderator}"

if [ "$ROLE" != "moderator" ] && [ "$ROLE" != "user" ]; then
    echo "Error: Role must be 'moderator' or 'user'"
    echo "Usage: $0 <username> <moderator|user>"
    exit 1
fi

# Check if JWT secret exists
if [ ! -f "${SECRETS_DIR}/jwt_app_secret" ]; then
    echo "Error: JWT secret not found. Please run ./setup.sh first."
    exit 1
fi

# Read JWT secret
JWT_APP_SECRET=$(cat "${SECRETS_DIR}/jwt_app_secret")

# Generate token using Python
python3 << EOF
import jwt
import time
import sys

# JWT configuration
APP_ID = "jitsi-meet"
APP_SECRET = "${JWT_APP_SECRET}"
USERNAME = "${USERNAME}"
ROLE = "${ROLE}"
PUBLIC_URL = "https://jitsi.macbookpro:30443"

# Token payload
payload = {
    "iss": APP_ID,
    "aud": APP_ID,
    "sub": "jitsi.macbookpro",
    "room": "*",
    "context": {
        "user": {
            "id": USERNAME,
            "name": USERNAME,
            "email": f"{USERNAME}@example.com",
            "moderator": ROLE == "moderator"
        }
    },
    "iat": int(time.time()),
    "exp": int(time.time()) + 86400  # 24 hours
}

# Generate token
token = jwt.encode(payload, APP_SECRET, algorithm="HS256")

# Print token
if isinstance(token, bytes):
    token = token.decode('utf-8')

print("\n" + "="*60)
print(f"JWT Token for user: {USERNAME} (role: {ROLE})")
print("="*60)
print("\nToken:")
print(token)
print("\n" + "="*60)
print("\nTo use this token, append it to the Jitsi URL:")
print(f"{PUBLIC_URL}/<room-name>?jwt={token}")
print("\nExample:")
print(f"{PUBLIC_URL}/testroom?jwt={token}")
print("\nToken expires in 24 hours.")
print("="*60 + "\n")
EOF
