# Jitsi Kubernetes Scalability Project - Agent Instructions

## Project Overview

This is a Kubernetes deployment project for Jitsi Meet with JWT authentication and horizontal scalability (JVB auto-scaling 2-10 replicas). The project is structured with the main Kubernetes manifests in `jitsi-k8s/`.

## Repository Structure

```
jitsi-scalability/
├── jitsi-k8s/                # Main Kubernetes deployment
│   ├── k8s/                  # Ordered manifests (00-07)
│   ├── scripts/              # Deployment helper scripts
│   ├── certs/                # TLS certificates (generated)
│   └── .secrets/             # JWT secrets (generated)
├── create_instances.sh       # External instance creation script
├── run.sh                    # Runner script
└── user_data.sh              # User data script
```

## Key Commands

### Full Deployment
```bash
cd jitsi-k8s
./scripts/setup.sh                    # Deploys all Kubernetes resources
./scripts/install-ca-macos.sh         # Install CA in System Keychain (sudo)
./scripts/generate-jwt-token.sh <user> <moderator|user>
```

### Verification
```bash
kubectl get all -n jitsi              # Check all resources
kubectl get hpa -n jitsi              # Check HPA status
kubectl top pods -n jitsi             # Resource usage
kubectl logs -n jitsi -l component=<web|prosody|jicofo|jvb>
```

### Cleanup
```bash
./scripts/cleanup.sh                  # Remove Kubernetes resources
```

## Manifest Deployment Order

The numbered manifests must be applied in order:
1. `00-namespace.yaml` - jitsi namespace
2. `01-nginx-ingress-controller.yaml` - ingress controller
3. `02-configmaps.yaml` - component configurations
4. `03-secrets.yaml` - TLS + JWT secrets (generated from template)
5. `04-deployments.yaml` - all component deployments
6. `05-services.yaml` - service definitions
7. `06-hpa.yaml` - JVB auto-scaling
8. `07-ingress.yaml` - HTTPS routing

## Architecture Components

- **jitsi-web**: Frontend (nginx + React), 1 replica
- **prosody**: XMPP server with JWT auth, 1 replica
- **jicofo**: Conference focus controller, 1 replica
- **jvb**: Videobridge (media), 2-10 replicas with HPA

Access: `https://jitsi.macbookpro` (requires `/etc/hosts` entry)

## JVB Auto-Scaling Configuration

- **Min replicas**: 2
- **Max replicas**: 10
- **Target CPU**: 70%
- **Target Memory**: 80%
- **Scale-down stabilization**: 5 minutes

## TLS Certificate Flow

1. `generate-ca.sh` - Creates local CA
2. `generate-certs.sh` - Signs server cert for jitsi.macbookpro
3. `install-ca-macos.sh` - Adds CA to System Keychain
4. Certs stored in `certs/` and mounted as Kubernetes Secrets

## JWT Authentication

- Algorithm: HS256
- Issuer/Audience: `jitsi-meet`
- Token lifetime: 24 hours
- Use `scripts/generate-jwt-token.sh` to create tokens
- Token format: `https://jitsi.macbookpro/<room>?jwt=<token>`

## Prerequisites

- macOS with Docker Desktop (Kubernetes enabled)
- kubectl, openssl, Python 3 with PyJWT
- `/etc/hosts` entry: `127.0.0.1 jitsi.macbookpro`

## Troubleshooting

```bash
# Check HPA requires metrics-server
kubectl get deployment metrics-server -n kube-system

# For Docker Desktop, patch metrics-server:
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Debug ingress
kubectl describe ingress jitsi-ingress -n jitsi

# Check events
kubectl get events -n jitsi --sort-by='.lastTimestamp'
```
